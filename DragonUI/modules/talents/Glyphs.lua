-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local L = addon.L
local T = addon.TalentModule

local TEX = addon._dir .. "Talents\\"
local RING = TEX .. "glyph-ring-gold"
local RING_DESAT = TEX .. "glyph-ring-desat"
local GLOBE = { [true] = TEX .. "glyph-globe-health", [false] = TEX .. "glyph-globe-mana" }
local GLOSS = TEX .. "glyph-orbgloss"
local CLASS_ART = TEX .. "Artifact\\"
local CARD = TEX .. "glyph-effects-card"

local GLYPH_MAJOR, GLYPH_MINOR = 1, 2
local RING_SCALE = 1.8
-- Hub lines stop inside the ring's opaque band (0.51-0.65 of its half-size), so no end ever shows.
local RING_ART_FRAC = 0.6
local EDGE_WIDTH = 64

-- New Era's health/mana globes, re-sampled from 44px to 80px cells (12 per row, 2px apart).
local GLOBE_FRAMES, GLOBE_COLS, GLOBE_CELL, GLOBE_STRIDE, GLOBE_PAD = 67, 12, 80, 84, 2
local GLOBE_W, GLOBE_H = 1024, 512
local GLOBE_FPS = 30

-- New Era's 440px card, pre-widened with native trim: scaling the 260px art at runtime blurs it.
local CARD_W, CARD_TOP_H, CARD_BOTTOM_H = 440, 100, 99
local CARD_U = CARD_W / 512

local CLASS_FILE = {
    WARRIOR = "Warrior", PALADIN = "Paladin", HUNTER = "Hunter", ROGUE = "Rogue", PRIEST = "Priest",
    DEATHKNIGHT = "DeathKnight", SHAMAN = "Shaman", MAGE = "Mage", WARLOCK = "Warlock", DRUID = "Druid",
}

-- Display slots around the hub: odd = major triangle, even = minor triangle.
local POSITIONS = {
    { 0, 118 }, { 102, 60 }, { 102, -60 }, { 0, -118 }, { -102, -60 }, { -102, 60 },
}

local function globeCoord(i)
    local col = (i - 1) % GLOBE_COLS
    local row = math.floor((i - 1) / GLOBE_COLS)
    local x, y = col * GLOBE_STRIDE + GLOBE_PAD, row * GLOBE_STRIDE + GLOBE_PAD
    return x / GLOBE_W, (x + GLOBE_CELL) / GLOBE_W, y / GLOBE_H, (y + GLOBE_CELL) / GLOBE_H
end

local function config()
    local p = addon.db and addon.db.profile
    return p and p.talents or {}
end

-- ============================================================================
-- View state
-- ============================================================================
local root, pane, list
local paintSpecSwitch, buildSpecSwitch

function T.GlyphViewActive() return T._glyphView and true or false end

function T.SetGlyphView(on)
    on = on and true or false
    if T._glyphView == on then return end
    T._glyphView = on
    -- Glyphs open on the spec you are playing, not on whichever talent tab was clicked last.
    if on then T._viewGroup = nil end
    T.MarkDirty()
    local f = T.frame
    if not f then return end
    if root then root:SetShownReq(on) end
    if f.glyphBg then f.glyphBg:SetShownReq(on) end
    f.fx:SetShownReq(not on)
    if on then
        for _, tf in ipairs(f.trees) do tf:Hide() end
        f.bg:Hide()
        if f.petBg then f.petBg:Hide() end
    end
end

-- ============================================================================
-- Socket data
-- ============================================================================
local function socketInfo(socket, group)
    local enabled, glyphType, glyphSpell, icon = GetGlyphSocketInfo(socket, group)
    return {
        socket = socket, group = group, enabled = enabled and true or false,
        glyphType = glyphType, glyphSpell = glyphSpell, icon = icon,
    }
end

-- The item-name prefix is per locale; an empty translation keeps the full name.
local function glyphName(spellID)
    local name = spellID and GetSpellInfo(spellID)
    if not name then return nil end
    local prefix = L["Glyph of "]
    if prefix ~= "" and name:sub(1, #prefix) == prefix then name = name:sub(#prefix + 1) end
    return name
end

local descCache = {}
local scratch

-- Spell text only arrives once the client has the spell; an empty read is not cached.
local function glyphDescription(spellID)
    if descCache[spellID] then return descCache[spellID] end
    if not scratch then
        scratch = CreateFrame("GameTooltip", "DragonUI_GlyphScratchTooltip", nil, "GameTooltipTemplate")
    end
    scratch:SetOwner(WorldFrame, "ANCHOR_NONE")
    scratch:ClearLines()
    scratch:SetHyperlink("spell:" .. spellID)
    local desc
    for k = scratch:NumLines(), 2, -1 do
        local line = _G["DragonUI_GlyphScratchTooltipTextLeft" .. k]
        local txt = line and line:GetText()
        if txt and txt ~= "" then
            desc = txt
            break
        end
    end
    scratch:Hide()
    if desc then descCache[spellID] = desc end
    return desc or ""
end

-- ============================================================================
-- Popups (Blizzard's own strings; theirs read PlayerTalentFrame.talentGroup, which is not ours)
-- ============================================================================
StaticPopupDialogs["DUI_GLYPH_REMOVE"] = {
    text = CONFIRM_REMOVE_GLYPH,
    button1 = YES, button2 = NO,
    OnAccept = function(_, socket) RemoveGlyphFromSocket(socket) end,
    hideOnEscape = 1, timeout = 0, exclusive = 1,
}

StaticPopupDialogs["DUI_GLYPH_REPLACE"] = {
    text = CONFIRM_GLYPH_PLACEMENT,
    button1 = YES, button2 = NO,
    OnAccept = function(_, socket) PlaceGlyphInSocket(socket) end,
    hideOnEscape = 1, timeout = 0, exclusive = 1,
}

-- ============================================================================
-- Sockets
-- ============================================================================
local function socketTooltip(b)
    if not b._info then return end
    GameTooltip:SetOwner(b, "ANCHOR_RIGHT")
    GameTooltip:SetGlyph(b._info.socket, b._info.group)
    GameTooltip:Show()
end

-- Blizzard's GlyphFrameGlyph_OnClick, against our view group instead of PlayerTalentFrame's.
local function socketClick(b, button)
    local info = b._info
    if not info then return end
    local socket, group = info.socket, info.group
    local isActive = group == (GetActiveTalentGroup(false, false) or 1)
    if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
        local link = GetGlyphLink(socket, group)
        if link then ChatEdit_InsertLink(link) end
    elseif button == "RightButton" then
        if IsShiftKeyDown() and isActive and info.glyphSpell then
            StaticPopup_Show("DUI_GLYPH_REMOVE", GetSpellInfo(info.glyphSpell), nil, socket)
        end
    elseif isActive then
        if info.glyphSpell and GlyphMatchesSocket(socket) then
            StaticPopup_Show("DUI_GLYPH_REPLACE", nil, nil, socket)
        else
            PlaceGlyphInSocket(socket)
        end
    end
end

local function buildSocket(parent, index)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(64, 64)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b._index = index

    b.Globe = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    b.Globe:SetTexture(GLOBE[true])
    b.Globe:SetPoint("CENTER")
    b.Globe:SetTexCoord(globeCoord(1))

    b.Icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
    b.Icon:SetPoint("CENTER")
    b.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.IconTint = b:CreateTexture(nil, "ARTWORK", nil, 2)
    b.IconTint:SetPoint("CENTER")
    b.IconTint:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.IconTint:SetBlendMode("ADD")
    b.IconTint:SetVertexColor(1.0, 0.84, 0.28)
    b.IconTint:Hide()

    b.Gloss = b:CreateTexture(nil, "ARTWORK", nil, 3)
    b.Gloss:SetTexture(GLOSS)
    b.Gloss:SetPoint("CENTER")

    b.Border = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.Border:SetPoint("CENTER")

    -- The pulse on inscribe/remove, and the "fits here" beat while a glyph waits on the cursor.
    b.Glow = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.Glow:SetTexture(RING)
    b.Glow:SetBlendMode("ADD")
    b.Glow:SetPoint("CENTER")
    b.Glow:SetAlpha(0)
    b.GlowPulse = b.Glow:CreateAnimationGroup()
    local flash = b.GlowPulse:CreateAnimation("Alpha")
    flash:SetChange(1); flash:SetDuration(0.1); flash:SetOrder(1)
    local fade = b.GlowPulse:CreateAnimation("Alpha")
    fade:SetChange(-1); fade:SetDuration(1.5); fade:SetOrder(2)

    b.Name = b:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
    b.Name:SetTextColor(0.95, 0.90, 0.75)
    b.Name:SetWidth(160)
    b.Name:Hide()
    if index == 1 then
        b.Name:SetPoint("BOTTOM", b, "TOP", 0, 8)
    elseif index == 4 then
        b.Name:SetPoint("TOP", b, "BOTTOM", 0, -10)
    elseif index == 2 or index == 3 then
        b.Name:SetPoint("LEFT", b, "RIGHT", 10, 0)
        b.Name:SetJustifyH("LEFT")
    else
        b.Name:SetPoint("RIGHT", b, "LEFT", -10, 0)
        b.Name:SetJustifyH("RIGHT")
    end

    b:SetScript("OnEnter", function(self)
        self._hovered = true
        if self._hasGlyph then
            self.Icon:SetAlpha(math.min(1, self._iconAlpha + 0.45))
            if self.IconTint:IsShown() then self.IconTint:SetAlpha(math.min(1, self._tintAlpha + 0.4)) end
        end
        socketTooltip(self)
    end)
    b:SetScript("OnLeave", function(self)
        self._hovered = nil
        self.Icon:SetAlpha(self._iconAlpha or 1)
        self.IconTint:SetAlpha(self._tintAlpha or 0)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", socketClick)
    return b
end

local SIZES = {
    [true]  = { button = 104, locked = 74, empty = 78, filled = 84, icon = 47, iconFilled = 52 },
    [false] = { button = 92,  locked = 57, empty = 57, filled = 65, icon = 30, iconFilled = 34 },
}

local function paintSocket(b, info, editable, major)
    b._info = info
    local s = SIZES[major]
    b:SetSize(s.button, s.button)
    local has = info.enabled and info.glyphSpell ~= nil
    local ring = (not info.enabled and s.locked) or (has and s.filled) or s.empty
    -- Only the ring's inner disc takes clicks; the frame is sized for its name label.
    local inset = math.max(0, math.floor((s.button - ring) / 2))
    b:SetHitRectInsets(inset, inset, inset, inset)

    b.Border:SetTexture(info.enabled and RING or RING_DESAT)
    b.Border:SetSize(ring * RING_SCALE, ring * RING_SCALE)
    local shade = info.enabled and 1 or 0.55
    b.Border:SetVertexColor(shade, shade, shade)
    b.Glow:SetSize(ring * RING_SCALE, ring * RING_SCALE)

    -- The other spec's glyphs read at full strength, as in Blizzard's frame; only the globe behind greys out.
    local lit = has and editable
    b.Globe:SetTexture(GLOBE[major])
    b.Globe:SetSize(ring, ring)
    b.Globe:SetDesaturated(not lit)
    b.Globe:SetAlpha(lit and 1 or 0.45)
    b.Gloss:SetSize(ring * 1.2, ring * 1.2)
    b.Gloss:SetAlpha(lit and 0.8 or 0.5)

    local iconSize = has and s.iconFilled * 0.9 or s.icon
    b.Icon:SetSize(iconSize, iconSize)
    local iconTex = has and info.icon or (major and "Interface\\Icons\\INV_Glyph_MajorGlyph" or "Interface\\Icons\\INV_Glyph_MinorGlyph")
    b.Icon:SetTexture(iconTex)
    b.Icon:SetDesaturated(not has)
    b._hasGlyph = has
    b._iconAlpha = has and 0.8 or (info.enabled and 0.8 or 0.6)
    b.Icon:SetAlpha(b._iconAlpha)
    if has then
        b.IconTint:SetSize(iconSize, iconSize)
        b.IconTint:SetTexture(iconTex)
        b._tintAlpha = major and 0.6 or 0.45
        b.IconTint:SetAlpha(b._tintAlpha)
        b.IconTint:Show()
    else
        b._tintAlpha = 0
        b.IconTint:Hide()
    end
    if b._hovered then b:GetScript("OnEnter")(b) end

    local name = has and config().glyph_names and glyphName(info.glyphSpell)
    b.Name:SetText(name or "")
    b.Name:SetShownReq(name and true or false)
    b:SetAlpha(info.enabled and 1 or 0.55)
end

-- ============================================================================
-- Hub lines between the socket triangles
-- ============================================================================
local function drawTriangle(p, first, color, slot)
    for k = 0, 2 do
        local a = first + 2 * k
        local b = first + 2 * ((k + 1) % 3)
        local ax, ay = POSITIONS[a][1], POSITIONS[a][2]
        local bx, by = POSITIONS[b][1], POSITIONS[b][2]
        local dx, dy = bx - ax, by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        local ux, uy = dx / len, dy / len
        local ra = p.sockets[a].Border:GetWidth() * 0.5 * RING_ART_FRAC
        local rb = p.sockets[b].Border:GetWidth() * 0.5 * RING_ART_FRAC
        local line = p.lines[slot + k]
        if not line then
            line = p:CreateTexture(nil, "ARTWORK", nil, -2)
            line:SetTexture(T.EDGE_LINE)
            p.lines[slot + k] = line
        end
        DrawRouteLine(line, p, ax + ux * ra, ay + uy * ra, bx - ux * rb, by - uy * rb, EDGE_WIDTH, "CENTER")
        line:SetVertexColor(color[1], color[2], color[3], color[4])
    end
end

local function drawLines(p, editable)
    local major = editable and { 1.0, 0.84, 0.18, 0.95 } or { 0.62, 0.49, 0.24, 0.45 }
    local minor = editable and { 1.0, 0.84, 0.18, 0.72 } or { 0.62, 0.49, 0.24, 0.32 }
    drawTriangle(p, 1, major, 1)
    drawTriangle(p, 2, minor, 4)
end

-- ============================================================================
-- Active effects card
-- ============================================================================
local function buildList(parent)
    local lf = CreateFrame("Frame", nil, parent)
    lf.card = CreateFrame("Frame", nil, lf)
    local function slice(name, l, r, t, b)
        local tex = lf.card:CreateTexture(nil, "BACKGROUND")
        tex:SetTexture(CARD)
        tex:SetTexCoord(l, r, t, b)
        lf.card[name] = tex
        return tex
    end
    local top = slice("Top", 0, CARD_U, 0, 100 / 256)
    top:SetPoint("TOPLEFT")
    top:SetPoint("TOPRIGHT")
    local bottom = slice("Bottom", 0, CARD_U, 132 / 256, 231 / 256)
    bottom:SetPoint("BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT")
    -- Sampled from inside a 32-row solid band: gaps next to a 1px strip bleed in once mipmaps kick in.
    local mid = slice("Mid", 0, CARD_U, 112 / 256, 120 / 256)
    mid:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    mid:SetPoint("BOTTOMRIGHT", bottom, "TOPRIGHT")

    lf.text = CreateFrame("Frame", nil, lf)
    lf.text:SetAllPoints(lf)
    lf.text:SetFrameLevel(lf.card:GetFrameLevel() + 1)
    lf.title = lf.text:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Large")
    lf.title:SetTextColor(1, 1, 1)
    lf.lines, lf.icons = {}, {}
    return lf
end

local function listLine(lf, i)
    local line = lf.lines[i]
    if not line then
        line = lf.text:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
        line:SetJustifyH("LEFT")
        lf.lines[i] = line
    end
    return line
end

local function listIcon(lf, i)
    local icon = lf.icons[i]
    if not icon then
        icon = lf.text:CreateTexture(nil, "OVERLAY")
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        lf.icons[i] = icon
    end
    return icon
end

local function paintList(group, width, height)
    local lf = list
    lf:ClearAllPoints()
    lf:SetPoint("TOPRIGHT", root, "TOPRIGHT")
    lf:SetSize(width, height)

    local majors, minors = {}, {}
    for socket = 1, GetNumGlyphSockets() or 0 do
        local info = socketInfo(socket, group)
        if info.enabled and info.glyphSpell then
            local entry = {
                name = glyphName(info.glyphSpell) or "?",
                desc = glyphDescription(info.glyphSpell),
                icon = info.icon,
            }
            if info.glyphType == GLYPH_MINOR then minors[#minors + 1] = entry else majors[#majors + 1] = entry end
        end
    end

    local cardX = math.floor((width - CARD_W) / 2)
    local PAD, ICON = 26, 26
    local INDENT = PAD + ICON + 8
    local entries = {}
    local function add(text, template, gap, indent, icon)
        entries[#entries + 1] = { text = text, template = template, gap = gap, indent = indent, icon = icon }
        return #entries
    end
    local function section(header, glyphs)
        add("|cffffcc55" .. header .. "|r", "SystemFont_Shadow_Large", (#entries > 0) and 28 or 0, PAD)
        if #glyphs == 0 then
            add("|cff808080" .. L["None active."] .. "|r", "SystemFont_Shadow_Med1", 8, INDENT)
            return
        end
        for _, g in ipairs(glyphs) do
            local first = add("|cffffd100" .. g.name .. "|r", "SystemFont_Shadow_Med1", 10, INDENT, g.icon)
            local last = first
            if g.desc ~= "" then last = add("|cffb3b3b3" .. g.desc .. "|r", "GameFontHighlightSmall", 4, INDENT) end
            entries[first].blockEnd = last
        end
    end

    local any = #majors > 0 or #minors > 0
    if any then
        lf.title:Hide()
        section(MAJOR_GLYPH, majors)
        section(MINOR_GLYPH, minors)
    else
        lf.title:SetText(L["NO ACTIVE EFFECTS"])
        lf.title:Show()
    end

    for _, line in ipairs(lf.lines) do line:Hide() end
    for _, icon in ipairs(lf.icons) do icon:Hide() end
    local heights, blockH = {}, any and 0 or (lf.title:GetStringHeight() or 0)
    for i, e in ipairs(entries) do
        local line = listLine(lf, i)
        line:SetFontObject(e.template)
        line:SetWidth(math.max(80, CARD_W - e.indent - PAD))
        line:SetText(e.text)
        heights[i] = line:GetStringHeight() or 0
        blockH = blockH + e.gap + heights[i]
    end

    local topY = math.max(24, math.floor((height - blockH) / 2))
    lf.title:ClearAllPoints()
    lf.title:SetPoint("TOP", lf, "TOPLEFT", cardX + CARD_W / 2, -topY)
    local y, tops = topY, {}
    for i, e in ipairs(entries) do
        y = y + e.gap
        local line = lf.lines[i]
        line:ClearAllPoints()
        line:SetPoint("TOPLEFT", lf, "TOPLEFT", cardX + e.indent, -y)
        line:Show()
        tops[i] = y
        y = y + heights[i]
    end
    for i, e in ipairs(entries) do
        if e.icon then
            local last = e.blockEnd or i
            local centre = (tops[i] + tops[last] + heights[last]) / 2
            local icon = listIcon(lf, i)
            icon:SetTexture(e.icon)
            icon:SetSize(ICON, ICON)
            icon:ClearAllPoints()
            icon:SetPoint("TOPLEFT", lf, "TOPLEFT", cardX + PAD, -(centre - ICON / 2))
            icon:Show()
        end
    end

    local bottomY = any and y or (topY + blockH)
    local cardTop, cardBottom = topY - 40, bottomY + 40
    local minH = CARD_TOP_H + CARD_BOTTOM_H
    if cardBottom - cardTop < minH then
        local c = (cardTop + cardBottom) / 2
        cardTop, cardBottom = c - minH / 2, c + minH / 2
    end
    lf.card.Top:SetHeight(CARD_TOP_H)
    lf.card.Bottom:SetHeight(CARD_BOTTOM_H)
    lf.card:ClearAllPoints()
    lf.card:SetPoint("TOPLEFT", lf, "TOPLEFT", cardX, -cardTop)
    lf.card:SetPoint("BOTTOMRIGHT", lf, "TOPLEFT", cardX + CARD_W, -cardBottom)
end

-- ============================================================================
-- Root
-- ============================================================================
-- Blizzard kept its spec tabs on screen over the glyph page; this pair does that job here.
local SWITCH_GAP = 36

function paintSpecSwitch(group)
    local sw = pane and pane.switch
    if not sw then return end
    local dual = (GetNumTalentGroups(false, false) or 1) >= 2
    sw:SetShownReq(dual)
    if not dual then return end
    local widths = {}
    for g, b in ipairs(sw.buttons) do
        b.text:SetText(string.upper(T.SpecName(g)))
        local on = g == group
        local c = on and 1 or (b._hover and 0.8 or 0.5)
        b.text:SetTextColor(c, c, c)
        b.line:SetShownReq(on)
        widths[g] = (b.text:GetStringWidth() or 0) + 8
        b:SetWidth(widths[g])
    end
    local total = widths[1] + SWITCH_GAP + widths[2]
    sw.buttons[1]:ClearAllPoints()
    sw.buttons[1]:SetPoint("LEFT", sw, "CENTER", -total / 2, 0)
    sw.buttons[2]:ClearAllPoints()
    sw.buttons[2]:SetPoint("LEFT", sw.buttons[1], "RIGHT", SWITCH_GAP, 0)
    sw.dot:ClearAllPoints()
    sw.dot:SetPoint("CENTER", sw.buttons[1], "RIGHT", SWITCH_GAP / 2, 0)
end

-- On the root so it hides with the glyph view, but seated in the footer, which is empty on this page.
function buildSpecSwitch(parent, bar)
    local sw = CreateFrame("Frame", nil, parent)
    sw:SetSize(1, 26)
    sw:SetPoint("CENTER", bar, "CENTER", 0, 0)
    sw:SetFrameLevel(bar:GetFrameLevel() + 2)
    sw.dot = sw:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Large")
    sw.dot:SetText("·")
    sw.dot:SetTextColor(0.5, 0.5, 0.5)
    sw.buttons = {}
    for g = 1, 2 do
        local b = CreateFrame("Button", nil, sw)
        b:SetID(g)
        b:SetHeight(26)
        b.text = b:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Large")
        b.text:SetPoint("CENTER")
        b.line = b:CreateTexture(nil, "ARTWORK")
        b.line:SetTexture(1, 0.82, 0, 0.9)
        b.line:SetHeight(2)
        b.line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 0)
        b.line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 0)
        b:SetScript("OnClick", function(self)
            if self:GetID() == (T.ViewGroup()) then return end
            PlaySound("igCharacterInfoTab")
            T.SetViewGroup(self:GetID())
            T.Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            self._hover = true
            paintSpecSwitch((T.ViewGroup()))
            if T.SpecTooltip then T.SpecTooltip(self) end
        end)
        b:SetScript("OnLeave", function(self)
            self._hover = nil
            paintSpecSwitch((T.ViewGroup()))
            GameTooltip:Hide()
        end)
        sw.buttons[g] = b
    end
    return sw
end

local function glyphOptions(anchor)
    local function toggle(key, fallback)
        return function()
            local cfg = config()
            local current = cfg[key]
            if current == nil then current = fallback end
            cfg[key] = not current
            T.GlyphsRefresh()
        end
    end
    addon.Menu.Open(anchor, {
        { text = L["Glyph options"], isTitle = true },
        { text = L["Show glyph names"], checked = function() return config().glyph_names end,
          func = toggle("glyph_names", false), keepShown = true },
        { text = L["Show glyph effects"], checked = function() return config().glyph_effects ~= false end,
          func = toggle("glyph_effects", true), keepShown = true },
    })
end

local function buildRoot(f)
    root = CreateFrame("Frame", "DragonUI_TalentGlyphRoot", f)
    root:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -T.FRAME.CHROME_T)
    root:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, T.FRAME.BOTTOMBAR_H)
    root:SetFrameLevel(f:GetFrameLevel() + 3)
    root:Hide()

    f.glyphBg = f:CreateTexture(nil, "BORDER")
    f.glyphBg:SetAllPoints(f.bg)
    f.glyphBg:SetTexture(CLASS_ART .. (CLASS_FILE[select(2, UnitClass("player"))] or "Warrior"))
    f.glyphBg:Hide()

    root.title = root:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Huge1")
    root.title:SetPoint("TOP", root, "TOP", 0, -28)
    root.title:SetTextColor(1, 1, 1)
    root.title:SetText(string.upper(GLYPHS))

    local cog = CreateFrame("Button", nil, root)
    cog:SetSize(18, 18)
    cog:SetPoint("TOPRIGHT", root, "TOPRIGHT", -8, -8)
    local gear = cog:CreateTexture(nil, "ARTWORK")
    gear:set_atlas("questlog-icon-setting", true)
    gear:SetPoint("CENTER")
    local glow = cog:CreateTexture(nil, "HIGHLIGHT")
    glow:set_atlas("questlog-icon-setting", true)
    glow:SetPoint("CENTER")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.4)
    cog:SetScript("OnClick", glyphOptions)
    cog:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Glyph options"], 1, 1, 1)
        GameTooltip:AddLine(L["Toggle slot name labels and the active-effects list."], 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function() GameTooltip:Hide() end)

    pane = CreateFrame("Frame", nil, root)
    pane.switch = buildSpecSwitch(root, f.barFrame)
    pane.sockets, pane.lines = {}, {}
    for i = 1, #POSITIONS do
        local b = buildSocket(pane, i)
        b:SetPoint("CENTER", pane, "CENTER", POSITIONS[i][1], POSITIONS[i][2])
        pane.sockets[i] = b
    end

    list = buildList(root)

    -- Runs only while the glyph view is on screen: the globes turn and a glyph on the cursor finds its sockets.
    local acc, frame = 0, 1
    root:SetScript("OnUpdate", function(_, elapsed)
        acc = acc + elapsed
        if acc < 1 / GLOBE_FPS then return end
        acc = 0
        frame = frame % GLOBE_FRAMES + 1
        local l, r, t, b = globeCoord(frame)
        local targeting = SpellIsTargeting()
        local pulse = 0.4 + 0.4 * math.abs(math.sin(GetTime() * 2))
        for _, s in ipairs(pane.sockets) do
            if s.Globe:IsShown() then s.Globe:SetTexCoord(l, r, t, b) end
            if not s.GlowPulse:IsPlaying() then
                local fits = targeting and s._info and s._info.enabled and GlyphMatchesSocket(s._info.socket)
                s.Glow:SetAlpha(fits and pulse or 0)
            end
            if s._hovered and targeting then
                SetCursor((s._info and GlyphMatchesSocket(s._info.socket)) and "CAST_CURSOR" or "CAST_ERROR_CURSOR")
            end
        end
    end)
end

function T.GlyphsRefresh()
    local f = T.frame
    if not (f and T.GlyphViewActive()) then return end
    if not root then buildRoot(f) end
    root:Show()
    f.glyphBg:Show()

    local group, active = T.ViewGroup()
    local editable = group == active
    local width, height = T.FRAME.W, f:GetHeight() - T.FRAME.CHROME_T - T.FRAME.BOTTOMBAR_H
    local showEffects = config().glyph_effects ~= false

    pane:ClearAllPoints()
    pane:SetPoint("TOPLEFT", root, "TOPLEFT")
    pane:SetSize(showEffects and math.floor(width / 2) or width, height)
    paintSpecSwitch(group)
    f.glyphBg:SetDesaturated(not editable)

    local majors, minors = {}, {}
    for socket = 1, GetNumGlyphSockets() or 0 do
        local info = socketInfo(socket, group)
        if info.glyphType == GLYPH_MINOR then minors[#minors + 1] = info else majors[#majors + 1] = info end
    end
    local nextMajor, nextMinor = 1, 1
    for i, b in ipairs(pane.sockets) do
        local major = (i % 2) == 1
        local info
        if major then
            info, nextMajor = majors[nextMajor], nextMajor + 1
        else
            info, nextMinor = minors[nextMinor], nextMinor + 1
        end
        if info then
            b:Show()
            paintSocket(b, info, editable, major)
        else
            b:Hide()
        end
    end
    drawLines(pane, editable)

    if showEffects then
        list:Show()
        paintList(group, math.floor(width / 2), height)
    else
        list:Hide()
    end
    T.SetTitle(GLYPHS)
end

local events = CreateFrame("Frame")
events:RegisterEvent("GLYPH_ADDED")
events:RegisterEvent("GLYPH_REMOVED")
events:RegisterEvent("GLYPH_UPDATED")
events:SetScript("OnEvent", function(_, event, socket)
    if not (T.applied and root and root:IsVisible()) then return end
    T.GlyphsRefresh()
    local _, glyphType = GetGlyphSocketInfo(socket)
    local minor = glyphType == GLYPH_MINOR
    if event == "GLYPH_REMOVED" then
        PlaySound(minor and "Glyph_MinorDestroy" or "Glyph_MajorDestroy")
    else
        PlaySound(minor and "Glyph_MinorCreate" or "Glyph_MajorCreate")
    end
    for _, b in ipairs(pane.sockets) do
        if b._info and b._info.socket == socket then
            b.GlowPulse:Stop()
            b.GlowPulse:Play()
            if GameTooltip:IsOwned(b) then socketTooltip(b) end
        end
    end
end)
