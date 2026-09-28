-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local abs, floor, max, min, sin, sqrt = math.abs, math.floor, math.max, math.min, math.sin, math.sqrt
local GetNumGlyphSockets = _G.GetNumGlyphSockets

local root, pane, card, switch
local sockets, hubLines, slotOfSocket = {}, {}, {}
local cardLines, cardIcons = {}, {}
local descriptions = {}

-- Socket looks ------------------------------------------------------------------------------------

local function socketKind(size, lockedRing, emptyRing, filledRing, emptyIcon, filledIcon, globe, tint, placeholder)
    return {
        size = size, tint = tint,
        ring = { locked = lockedRing, empty = emptyRing, filled = filledRing },
        icon = { empty = emptyIcon, filled = filledIcon },
        globe = "Talents\\" .. globe,
        placeholder = "Interface\\Icons\\INV_Glyph_" .. placeholder,
    }
end
local MAJOR = socketKind(104, 74, 78, 84, 47, 46.8, "glyph-globe-health", 0.6, "MajorGlyph")
local MINOR = socketKind(92, 57, 57, 65, 30, 30.6, "glyph-globe-mana", 0.45, "MinorGlyph")

-- Offsets from the pane's centre; odd slots hold the major triangle, even slots the minor one.
local SLOT_XY = { { 0, 118 }, { 102, 60 }, { 102, -60 }, { 0, -118 }, { -102, -60 }, { -102, 60 } }
local HUB_PAIRS = { { 1, 3 }, { 3, 5 }, { 5, 1 }, { 2, 4 }, { 4, 6 }, { 6, 2 } }

-- 67 globe frames, 12 per row, 80-px cells on an 84-px stride with a 2-px pad (1024x512 sheet).
local GLOBE_FRAMES = {}
for i = 1, 67 do
    local x, y = ((i - 1) % 12) * 84 + 2, floor((i - 1) / 12) * 84 + 2
    GLOBE_FRAMES[i] = { x / 1024, (x + 80) / 1024, y / 512, (y + 80) / 512 }
end

local function glyphName(spell)
    local name = spell and GetSpellInfo(spell)
    if not name then return "?" end
    local prefix = L["Glyph of "]
    if prefix ~= "" and name:sub(1, #prefix) == prefix then
        name = name:sub(#prefix + 1)
    end
    return name
end

-- Spell text arrives late, so only a non-empty read is cached.
local function glyphDescription(spell)
    if descriptions[spell] then return descriptions[spell] end
    local scratch = _G.DragonUI_GlyphScratchTooltip
    if not scratch then
        scratch = CreateFrame("GameTooltip", "DragonUI_GlyphScratchTooltip", UIParent, "GameTooltipTemplate")
    end
    scratch:SetOwner(UIParent, "ANCHOR_NONE")
    scratch:SetHyperlink("spell:" .. spell)
    local found = ""
    for line = scratch:NumLines(), 2, -1 do
        local region = _G["DragonUI_GlyphScratchTooltipTextLeft" .. line]
        local text = region and region:GetText()
        if text and text:find("%S") then
            found = text
            break
        end
    end
    scratch:Hide()
    if found ~= "" then descriptions[spell] = found end
    return found
end

-- Sockets -----------------------------------------------------------------------------------------

local function socketTooltip(button)
    local tip = GameTooltip
    tip:SetOwner(button, "ANCHOR_RIGHT")
    tip:SetGlyph(button.socket, ns.viewGroup)
end

local function applyHover(button)
    if button.hovered and button.hasGlyph then
        button.icon:SetAlpha(min(1, button.iconAlpha + 0.45))
        button.tint:SetAlpha(min(1, button.tintAlpha + 0.4))
    else
        button.icon:SetAlpha(button.iconAlpha)
        button.tint:SetAlpha(button.tintAlpha)
    end
end

local function socketClicked(button, mouse)
    local socket, group = button.socket, ns.viewGroup
    if not socket then return end
    local active = group == ns.ActiveGroup()
    if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() then
        local link = GetGlyphLink(socket, group)
        if link then ChatEdit_InsertLink(link) end
    elseif mouse == "RightButton" then
        if IsShiftKeyDown() and active and button.hasGlyph then
            local _, _, spell = GetGlyphSocketInfo(socket, group)
            if spell then StaticPopup_Show("DUI_GLYPH_REMOVE", GetSpellInfo(spell), nil, socket) end
        end
    elseif active then
        if button.hasGlyph and GlyphMatchesSocket(socket) then
            StaticPopup_Show("DUI_GLYPH_REPLACE", nil, nil, socket)
        else
            PlaceGlyphInSocket(socket)
        end
    end
end

local function newSocket(slot)
    local button = CreateFrame("Button", nil, pane)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:SetPoint("CENTER", pane, "CENTER", SLOT_XY[slot][1], SLOT_XY[slot][2])
    button.slot = slot

    button.globe = button:CreateTexture(nil, "BACKGROUND", nil, -1)
    button.icon = button:CreateTexture(nil, "ARTWORK", nil, 1)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.tint = button:CreateTexture(nil, "ARTWORK", nil, 2)
    button.tint:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.tint:SetBlendMode("ADD")
    button.tint:SetVertexColor(1.0, 0.84, 0.28)
    button.gloss = button:CreateTexture(nil, "ARTWORK", nil, 3)
    button.gloss:SetTexture(addon._dir .. "Talents\\glyph-orbgloss")
    button.ring = button:CreateTexture(nil, "OVERLAY", nil, 1)
    button.glow = button:CreateTexture(nil, "OVERLAY", nil, 2)
    button.glow:SetTexture(addon._dir .. "Talents\\glyph-ring-gold")
    button.glow:SetBlendMode("ADD")
    button.glow:SetAlpha(0)
    for _, tex in ipairs({ button.globe, button.icon, button.tint, button.gloss, button.ring, button.glow }) do
        tex:SetPoint("CENTER", button, "CENTER", 0, 0)
    end

    local flash = button.glow:CreateAnimationGroup()
    local flare = flash:CreateAnimation("Alpha")
    flare:SetOrder(1)
    flare:SetDuration(0.1)
    flare:SetChange(1)
    local ebb = flash:CreateAnimation("Alpha")
    ebb:SetOrder(2)
    ebb:SetDuration(1.5)
    ebb:SetChange(-1)
    button.flash = flash

    local label = button:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Med1")
    label:SetTextColor(0.95, 0.90, 0.75)
    label:SetWidth(160)
    if slot == 1 then
        label:SetPoint("BOTTOM", button, "TOP", 0, 8)
    elseif slot == 4 then
        label:SetPoint("TOP", button, "BOTTOM", 0, -10)
    elseif slot <= 3 then
        label:SetPoint("LEFT", button, "RIGHT", 10, 0)
        label:SetJustifyH("LEFT")
    else
        label:SetPoint("RIGHT", button, "LEFT", -10, 0)
        label:SetJustifyH("RIGHT")
    end
    button.label = label

    button.iconAlpha, button.tintAlpha = 1, 0
    button:SetScript("OnClick", socketClicked)
    button:SetScript("OnEnter", function(self)
        self.hovered = true
        applyHover(self)
        socketTooltip(self)
    end)
    button:SetScript("OnLeave", function(self)
        self.hovered = false
        applyHover(self)
        GameTooltip_Hide()
    end)
    return button
end

local function paintSocket(button, socket, group, activeGroup, showNames)
    button.socket = socket
    local enabled, glyphType, spell, icon = GetGlyphSocketInfo(socket, group)
    local kind = glyphType == 2 and MINOR or MAJOR
    local hasGlyph = enabled and spell and true or false
    local lit = hasGlyph and group == activeGroup
    local ring = (not enabled and kind.ring.locked) or (hasGlyph and kind.ring.filled) or kind.ring.empty
    button.enabled, button.hasGlyph, button.ringSize = enabled and true or false, hasGlyph, ring

    button:SetSize(kind.size, kind.size)
    local inset = floor((kind.size - ring) / 2)
    button:SetHitRectInsets(inset, inset, inset, inset)

    button.ring:SetTexture(addon._dir .. (enabled and "Talents\\glyph-ring-gold" or "Talents\\glyph-ring-desat"))
    button.ring:SetSize(ring * 1.8, ring * 1.8)
    local shade = enabled and 1 or 0.55
    button.ring:SetVertexColor(shade, shade, shade)
    button.glow:SetSize(ring * 1.8, ring * 1.8)

    button.globe:SetTexture(addon._dir .. kind.globe)
    button.globe:SetSize(ring, ring)
    button.globe:SetDesaturated(not lit)
    button.globe:SetAlpha(lit and 1 or 0.45)
    button.gloss:SetSize(ring * 1.2, ring * 1.2)
    button.gloss:SetAlpha(lit and 0.8 or 0.5)

    local iconSize = hasGlyph and kind.icon.filled or kind.icon.empty
    button.icon:SetSize(iconSize, iconSize)
    button.icon:SetTexture(hasGlyph and icon or kind.placeholder)
    button.icon:SetDesaturated(not hasGlyph)
    button.iconAlpha = (hasGlyph or enabled) and 0.8 or 0.6
    if hasGlyph then
        button.tint:SetTexture(icon)
        button.tint:SetSize(iconSize, iconSize)
        button.tint:Show()
        button.tintAlpha = kind.tint
    else
        button.tint:Hide()
        button.tintAlpha = 0
    end
    applyHover(button)
    button:SetAlpha(enabled and 1 or 0.55)

    if showNames and hasGlyph then
        button.label:SetText(glyphName(spell))
        button.label:Show()
    else
        button.label:Hide()
    end
    button:Show()
end

-- Hub lines ---------------------------------------------------------------------------------------

local function drawHub(active)
    for index, pair in ipairs(HUB_PAIRS) do
        local line = hubLines[index]
        local a, b = sockets[pair[1]], sockets[pair[2]]
        if a:IsShown() and b:IsShown() then
            local ax, ay = SLOT_XY[pair[1]][1], SLOT_XY[pair[1]][2]
            local bx, by = SLOT_XY[pair[2]][1], SLOT_XY[pair[2]][2]
            local dx, dy = bx - ax, by - ay
            local length = sqrt(dx * dx + dy * dy)
            dx, dy = dx / length, dy / length
            -- Pull each end inside its ring's opaque band: 0.6 of half the 1.8x ring texture.
            local trimA, trimB = a.ringSize * 0.54, b.ringSize * 0.54
            DrawRouteLine(line, pane, ax + dx * trimA, ay + dy * trimA, bx - dx * trimB, by - dy * trimB, 64, "CENTER")
            local minor = pair[1] % 2 == 0
            if active then
                line:SetVertexColor(1.0, 0.84, 0.18, minor and 0.72 or 0.95)
            else
                line:SetVertexColor(0.62, 0.49, 0.24, minor and 0.32 or 0.45)
            end
            line:Show()
        else
            line:Hide()
        end
    end
end

-- Effects card ------------------------------------------------------------------------------------

local CARD_X, CARD_W = 60, 440
local LINE_STYLE = {
    header = { font = "SystemFont_Shadow_Large", rgb = { 1, 0.8, 0.333 }, gap = 28, indent = 26 },
    name = { font = "SystemFont_Shadow_Med1", rgb = { 1, 0.82, 0 }, gap = 10, indent = 60 },
    desc = { font = "GameFontHighlightSmall", rgb = { 0.7, 0.7, 0.7 }, gap = 4, indent = 60 },
    none = { font = "SystemFont_Shadow_Med1", rgb = { 0.5, 0.5, 0.5 }, gap = 8, indent = 60 },
    empty = { font = "SystemFont_Shadow_Large", rgb = { 1, 1, 1 }, gap = 0, indent = 26 },
}

local function cardString(index, style)
    local text = cardLines[index]
    if not text then
        text = card:CreateFontString(nil, "OVERLAY")
        cardLines[index] = text
    end
    text:SetFontObject(style.font)
    text:SetTextColor(style.rgb[1], style.rgb[2], style.rgb[3])
    text:SetWidth(max(80, CARD_W - style.indent - 26))
    text:ClearAllPoints()
    return text
end

local function cardIcon(index)
    local icon = cardIcons[index]
    if not icon then
        icon = card:CreateTexture(nil, "OVERLAY")
        icon:SetSize(26, 26)
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        cardIcons[index] = icon
    end
    return icon
end

local function activeGlyphs(group)
    local majors, minors, count = {}, {}, GetNumGlyphSockets() or 0
    for socket = 1, count do
        local enabled, glyphType, spell, icon = GetGlyphSocketInfo(socket, group)
        if enabled and spell then
            local list = glyphType == 2 and minors or majors
            list[#list + 1] = { name = glyphName(spell), icon = icon, text = glyphDescription(spell) }
        end
    end
    return majors, minors
end

local function cardRows(group)
    local majors, minors = activeGlyphs(group)
    local rows = {}
    if #majors + #minors == 0 then
        rows[1] = { kind = "empty", text = L["NO ACTIVE EFFECTS"] }
        return rows
    end
    for _, section in ipairs({ { MAJOR_GLYPH, majors }, { MINOR_GLYPH, minors } }) do
        rows[#rows + 1] = { kind = "header", text = section[1] }
        if #section[2] == 0 then
            rows[#rows + 1] = { kind = "none", text = L["None active."] }
        end
        for _, glyph in ipairs(section[2]) do
            rows[#rows + 1] = { kind = "name", text = glyph.name, icon = glyph.icon }
            if glyph.text ~= "" then rows[#rows + 1] = { kind = "desc", text = glyph.text } end
        end
    end
    return rows
end

local function placeCardSlice(slice, top, height)
    slice:ClearAllPoints()
    slice:SetPoint("TOPLEFT", card, "TOPLEFT", CARD_X, -top)
    slice:SetSize(CARD_W, height)
end

local function paintCard(group, height)
    local rows = cardRows(group)
    local cursor = 0
    for index, row in ipairs(rows) do
        local style = LINE_STYLE[row.kind]
        local text = cardString(index, style)
        text:SetText(row.text)
        text:SetJustifyH(row.kind == "empty" and "CENTER" or "LEFT")
        row.top = cursor + (index > 1 and style.gap or 0)
        row.height = text:GetStringHeight()
        cursor = row.top + row.height
        row.widget, row.style = text, style
    end
    local blockTop = max(24, floor((height - cursor) / 2))

    local iconCount = 0
    for index, row in ipairs(rows) do
        local x = row.kind == "empty" and CARD_X + CARD_W / 2 or CARD_X + row.style.indent
        local point = row.kind == "empty" and "TOP" or "TOPLEFT"
        row.widget:SetPoint(point, card, "TOPLEFT", x, -(blockTop + row.top))
        row.widget:Show()
        if row.kind == "name" then
            local following = rows[index + 1]
            local bottom = row.top + row.height
            if following and following.kind == "desc" then bottom = following.top + following.height end
            iconCount = iconCount + 1
            local icon = cardIcon(iconCount)
            icon:SetTexture(row.icon)
            icon:ClearAllPoints()
            icon:SetPoint("LEFT", card, "TOPLEFT", CARD_X + 26, -(blockTop + (row.top + bottom) / 2))
            icon:Show()
        end
    end
    for index = #rows + 1, #cardLines do cardLines[index]:Hide() end
    for index = iconCount + 1, #cardIcons do cardIcons[index]:Hide() end

    local top, bottom = blockTop - 40, blockTop + cursor + 40
    if bottom - top < 199 then
        local pad = (199 - (bottom - top)) / 2
        top, bottom = top - pad, bottom + pad
    end
    placeCardSlice(card.head, top, 100)
    placeCardSlice(card.foot, bottom - 99, 99)
    card.body:ClearAllPoints()
    card.body:SetPoint("TOPLEFT", card.head, "BOTTOMLEFT", 0, 0)
    card.body:SetPoint("BOTTOMRIGHT", card.foot, "TOPRIGHT", 0, 0)
end

local function buildCard()
    card = CreateFrame("Frame", nil, root)
    card:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    card:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", 0, 0)
    card:SetWidth(560)
    local file = addon._dir .. "Talents\\glyph-effects-card"
    -- Rows 112-120 sit inside the solid band, so the stretched middle never bleeds mip edges.
    for key, v in pairs({ head = { 0, 0.390625 }, body = { 0.4375, 0.46875 }, foot = { 0.515625, 0.90234375 } }) do
        local slice = card:CreateTexture(nil, "BACKGROUND")
        slice:SetTexture(file)
        slice:SetTexCoord(0, 0.859375, v[1], v[2])
        card[key] = slice
    end
end

-- Spec switch in the footer -----------------------------------------------------------------------

local function switchColors()
    for group = 1, 2 do
        local button = switch.buttons[group]
        if group == ns.viewGroup then
            button.text:SetTextColor(1, 1, 1)
            button.underline:Show()
        else
            local grey = button.hovered and 0.8 or 0.5
            button.text:SetTextColor(grey, grey, grey)
            button.underline:Hide()
        end
    end
end

local function buildSwitch()
    switch = CreateFrame("Frame", nil, ns.footer)
    switch:SetFrameLevel(ns.footer:GetFrameLevel() + 2)
    switch:SetHeight(26)
    switch:SetPoint("CENTER", ns.footer, "CENTER", 0, 0)
    switch.buttons = {}
    for group = 1, 2 do
        local button = CreateFrame("Button", nil, switch)
        button:SetHeight(26)
        button.text = button:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Large")
        button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
        local line = button:CreateTexture(nil, "OVERLAY")
        line:SetTexture(1, 0.82, 0, 0.9)
        line:SetHeight(2)
        line:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 2, 0)
        line:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 0)
        button.underline = line
        button:SetScript("OnClick", function()
            if ns.viewGroup == group then return end
            PlaySound("igCharacterInfoTab")
            ns.viewGroup = group
            ns.Refresh()
        end)
        button:SetScript("OnEnter", function(self)
            self.hovered = true
            switchColors()
            ns.SpecTooltip(self, group)
        end)
        button:SetScript("OnLeave", function(self)
            self.hovered = false
            switchColors()
            GameTooltip_Hide()
        end)
        switch.buttons[group] = button
    end
    switch.buttons[1]:SetPoint("LEFT", switch, "LEFT", 0, 0)
    switch.buttons[2]:SetPoint("RIGHT", switch, "RIGHT", 0, 0)
    local dot = switch:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Large")
    dot:SetText("·")
    dot:SetTextColor(0.5, 0.5, 0.5)
    switch.dot = dot
    switch:Hide()
end

function ns.UpdateGlyphSwitch()
    if not switch then return end
    local shown = ns.GlyphView() and ns.PlayerGroups() >= 2
    switch:SetShownCompat(shown)
    if not shown then return end
    local widths = {}
    for group = 1, 2 do
        local button = switch.buttons[group]
        button.text:SetText(ns.SpecName(group):upper())
        widths[group] = button.text:GetStringWidth() + 8
        button:SetWidth(widths[group])
    end
    switch:SetWidth(widths[1] + 36 + widths[2])
    switch.dot:ClearAllPoints()
    switch.dot:SetPoint("CENTER", switch, "LEFT", widths[1] + 18, 0)
    switchColors()
end

-- Options cog -------------------------------------------------------------------------------------

local function flipOption(key, default)
    local profile = ns.Profile()
    local current = profile[key]
    if current == nil then current = default end
    profile[key] = not current
    TM.GlyphsRefresh()
end

local function optionsGear()
    local gear = ns.MakeCog(root)
    gear:SetPoint("TOPRIGHT", root, "TOPRIGHT", -8, -8)
    gear:SetScript("OnEnter", function(self)
        ns.TitledTip(self, L["Glyph options"], L["Toggle slot name labels and the active-effects list."])
    end)
    gear:SetScript("OnClick", function(self)
        addon.Menu.Open(self, {
            { text = L["Glyph options"], isTitle = true },
            {
                text = L["Show glyph names"], keepShown = true,
                checked = function() return ns.Profile().glyph_names == true end,
                func = function() flipOption("glyph_names", false) end,
            },
            {
                text = L["Show glyph effects"], keepShown = true,
                checked = function() return ns.Profile().glyph_effects ~= false end,
                func = function() flipOption("glyph_effects", true) end,
            },
        })
    end)
end

-- Root and animation ------------------------------------------------------------------------------

local function animate(self, elapsed)
    self.wait = self.wait + elapsed
    if self.wait < 0.0333 then return end
    self.wait = 0
    self.frame = self.frame % 67 + 1
    local coords = GLOBE_FRAMES[self.frame]
    local targeting = SpellIsTargeting()
    local beat = 0.4 + 0.4 * abs(sin(2 * GetTime()))
    for _, button in ipairs(sockets) do
        if button:IsShown() then
            button.globe:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            local fits = targeting and button.enabled and button.socket and GlyphMatchesSocket(button.socket)
            if not button.flash:IsPlaying() then
                button.glow:SetAlpha(fits and beat or 0)
            end
            if button.hovered and targeting then
                SetCursor(fits and "CAST_CURSOR" or "CAST_ERROR_CURSOR")
            end
        end
    end
end

local function buildRoot()
    local win = ns.win
    root = CreateFrame("Frame", "DragonUI_TalentGlyphRoot", win)
    root:SetFrameLevel(win:GetFrameLevel() + 3)
    root:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -ns.ART_TOP)
    root:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, ns.FOOTER_H)
    root:Hide()

    local heading = root:CreateFontString(nil, "OVERLAY", "SystemFont_Shadow_Huge1")
    heading:SetTextColor(1, 1, 1)
    heading:SetPoint("TOP", root, "TOP", 0, -28)
    heading:SetText(GLYPHS:upper())

    pane = CreateFrame("Frame", nil, root)
    pane:SetPoint("TOPLEFT", root, "TOPLEFT", 0, 0)
    pane:SetPoint("BOTTOMLEFT", root, "BOTTOMLEFT", 0, 0)
    for index = 1, #HUB_PAIRS do
        local line = pane:CreateTexture(nil, "ARTWORK", nil, -2)
        line:SetTexture(addon._dir .. "Talents\\talents-line")
        hubLines[index] = line
    end
    for slot = 1, 6 do sockets[slot] = newSocket(slot) end

    buildCard()
    optionsGear()
    buildSwitch()

    root.wait, root.frame = 0, 0
    root:SetScript("OnUpdate", animate)
end

function ns.HideGlyphRoot()
    if root then root:Hide() end
end

function ns.ShowGlyphRoot()
    if root then root:Show() end
end

function ns.PaintGlyphs()
    if not root then buildRoot() end
    local group, activeGroup = ns.viewGroup, ns.ActiveGroup()
    local classToken = ns.PlayerClass()
    ns.fx:Hide()
    ns.glyphArt:SetTexture(addon._dir .. "Talents\\Artifact\\" .. ns.ArtifactName(classToken))
    ns.glyphArt:SetTexCoord(0, 1, 0, 1)
    ns.glyphArt:SetDesaturated(group ~= activeGroup)
    ns.glyphArt:Show()
    ns.HideTrees()
    ns.classArt:Hide()
    ns.petArt:Hide()
    ns.SetPortraitClass(classToken)
    ns.SetTitle(GLYPHS)
    root:Show()

    local profile = ns.Profile()
    local effects = profile.glyph_effects ~= false
    pane:SetWidth(effects and 560 or ns.WIDTH)

    wipe(slotOfSocket)
    local nextMajor, nextMinor = 1, 2
    local bySlot = {}
    for socket = 1, GetNumGlyphSockets() or 0 do
        local _, glyphType = GetGlyphSocketInfo(socket, group)
        if glyphType == 2 then
            if nextMinor <= 6 then bySlot[nextMinor], nextMinor = socket, nextMinor + 2 end
        elseif nextMajor <= 5 then
            bySlot[nextMajor], nextMajor = socket, nextMajor + 2
        end
    end
    for slot = 1, 6 do
        local socket = bySlot[slot]
        if socket then
            slotOfSocket[socket] = slot
            paintSocket(sockets[slot], socket, group, activeGroup, profile.glyph_names == true)
        else
            sockets[slot].socket = nil
            sockets[slot]:Hide()
        end
    end
    drawHub(group == activeGroup)

    if effects then
        card:Show()
        paintCard(group, root:GetHeight())
    else
        card:Hide()
    end
end

TM.GlyphsRefresh = function()
    if ns.win and ns.win:IsShown() and ns.GlyphView() then ns.PaintGlyphs() end
end

-- Glyph events ------------------------------------------------------------------------------------

local function onGlyphEvent(event, socket)
    if not root or not root:IsVisible() then return end
    ns.PaintGlyphs()
    socket = tonumber(socket)
    if not socket then return end
    local _, glyphType = GetGlyphSocketInfo(socket, ns.ActiveGroup())
    local size = glyphType == 2 and "Minor" or "Major"
    PlaySound("Glyph_" .. size .. (event == "GLYPH_REMOVED" and "Destroy" or "Create"))
    local button = slotOfSocket[socket] and sockets[slotOfSocket[socket]]
    if not button then return end
    button.flash:Stop()
    button.glow:SetAlpha(0)
    button.flash:Play()
    if GameTooltip:IsOwned(button) then socketTooltip(button) end
end

function ns.InstallGlyphEvents()
    ns.Listen("GLYPH_ADDED", onGlyphEvent)
    ns.Listen("GLYPH_REMOVED", onGlyphEvent)
    ns.Listen("GLYPH_UPDATED", onGlyphEvent)
end

ns.DefinePopup("DUI_GLYPH_REMOVE", CONFIRM_REMOVE_GLYPH, YES, NO,
    { OnAccept = function(_, socket) RemoveGlyphFromSocket(socket) end }, "solo")

ns.DefinePopup("DUI_GLYPH_REPLACE", CONFIRM_GLYPH_PLACEMENT, YES, NO,
    { OnAccept = function(_, socket) PlaceGlyphInSocket(socket) end }, "solo")
