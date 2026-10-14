-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Combo points as retail's orb bar under the player frame and/or Forever's gem arc on the target portrait.

local addon = select(2, ...)
local L = addon.L
local UF = addon.UF

local KEY = "combopoints"
local ART = addon._dir .. "UnitFrames\\ComboPoints\\"
local GEM_TEXTURE = "Interface\\ComboFrame\\ComboPoint"
local MAX_POINTS = 5
local SHEET_W, SHEET_H = 1024, 512
local PIP_SIZE, PIP_SPACING = 20, 4
-- Bar centre on PlayerFrame's BOTTOM: the row DragonUI gives the DK runes.
local BAR_X, BAR_Y = 45, 15
-- In cat form the druid's mana bar takes that row, so their orbs sit lower.
local DRUID_BAR_DROP = 9
local POWER_ENERGY = 3
local PREVIEW_POINTS = 3
-- ComboFrame.lua's COMBOFRAME_FADE_IN, COMBOFRAME_HIGHLIGHT_FADE_IN and COMBOFRAME_SHINE_FADE_IN/OUT.
local FADE_IN = 0.3
local GEM_HIGHLIGHT_IN, GEM_SHINE_IN, GEM_SHINE_OUT = 0.4, 0.3, 0.4
-- Forever's 5-point arc (camelot anchor + mainline ComboPoints[2..6]) round the centre of its 58-unit portrait.
local ARC = { { -3.5, 37 }, { 9, 36 }, { 20.5, 30.5 }, { 29.5, 22 }, { 35, 10.5 } }
local ARC_PORTRAIT = 58

local floor, min = math.floor, math.min

-- =============================================================================
-- Art
-- =============================================================================

-- Sheet rects in px; the pieces are 2x art drawn at their 1x atlas sizes.
local RETAIL_RECTS = {
    rogue_slash     = { 0, 0, 516, 258 },
    druid_slash     = { 0, 262, 416, 246 },
    rogue_shadow    = { 524, 0, 50, 50 },
    rogue_bg        = { 578, 0, 40, 40 },
    rogue_bgdis     = { 622, 0, 40, 40 },
    rogue_frameglow = { 666, 0, 46, 46 },
    rogue_icon      = { 716, 0, 28, 29 },
    rogue_fx        = { 748, 0, 28, 28 },
    druid_shadow    = { 524, 56, 50, 50 },
    druid_bg        = { 578, 56, 40, 40 },
    druid_bgdis     = { 622, 56, 40, 40 },
    druid_ringglow  = { 666, 56, 46, 46 },
    druid_icon      = { 716, 56, 28, 28 },
    druid_deplete   = { 748, 56, 31, 30 },
    druid_bgglow    = { 783, 56, 72, 72 },
    druid_smoke     = { 524, 132, 43, 96 },
}

local FOREVER_RECTS = {
    rogue_slash     = { 0, 0, 516, 258 },
    rogue_shadow    = { 524, 0, 50, 50 },
    rogue_bg        = { 578, 0, 44, 44 },
    rogue_bgdis     = { 626, 0, 44, 44 },
    rogue_frameglow = { 674, 0, 44, 44 },
    rogue_icon      = { 722, 0, 28, 28 },
    rogue_fx        = { 754, 0, 28, 28 },
}

-- { key, piece, width, height, x, y, draw layer, on the pip's fx child }: retail's sublevels as layers and a child frame.
local ROGUE_LAYERS = {
    { "shadow", "rogue_shadow", 25, 25, 0, -4, "BACKGROUND" },
    { "bgActive", "rogue_bg", 20, 20, 0, 0, "BORDER" },
    { "bgInactive", "rogue_bgdis", 20, 20, 0, 0, "BORDER" },
    { "bgGlow", "rogue_bg", 20, 20, 0, 0, "ARTWORK" },
    { "icon", "rogue_icon", 14, 15, 0, 0, "OVERLAY" },
    { "fx", "rogue_fx", 14, 14, 0, 0, "BACKGROUND", true },
    { "frameGlow", "rogue_frameglow", 23, 23, 0, 0, "ARTWORK", true },
    { "slash", "rogue_slash", 43, 43, 0, 0, "OVERLAY", true },
}

local FOREVER_LAYERS = {
    { "shadow", "rogue_shadow", 25, 25, 0, -4, "BACKGROUND" },
    { "bgActive", "rogue_bg", 22, 22, 0, 0, "BORDER" },
    { "bgInactive", "rogue_bgdis", 22, 22, 0, 0, "BORDER" },
    { "bgGlow", "rogue_bg", 22, 22, 0, 0, "ARTWORK" },
    { "icon", "rogue_icon", 14, 14, 0, 0, "OVERLAY" },
    { "fx", "rogue_fx", 14, 14, 0, 0, "BACKGROUND", true },
    { "frameGlow", "rogue_frameglow", 22, 22, 0, 0, "ARTWORK", true },
    { "slash", "rogue_slash", 43, 43, 0, 0, "OVERLAY", true },
}

local DRUID_LAYERS = {
    { "shadow", "druid_shadow", 25, 25, 0, -2, "BACKGROUND" },
    { "bgActive", "druid_bg", 22, 22, 0, 0, "BORDER" },
    { "bgInactive", "druid_bgdis", 22, 22, 0, 0, "BORDER" },
    { "bgGlow", "druid_bgglow", 36, 36, 0, 0, "ARTWORK" },
    { "deplete", "druid_deplete", 16, 15, 0, 0, "ARTWORK" },
    { "icon", "druid_icon", 14, 14, 0, 0, "OVERLAY" },
    { "ringGlow", "druid_ringglow", 23, 23, 0, 0, "BACKGROUND", true },
    { "slash", "druid_slash", 26, 41, 1, 3, "ARTWORK", true },
    { "smoke", "druid_smoke", 22, 48, 0, 15, "OVERLAY", true },
}

-- { key, start, duration, from, to } alpha tracks from the mainline XML; before its first track a texture stays at 0.
local ROGUE_GAIN = {
    { "slash", 0, 0, 0, 1 },
    { "icon", 0, 0.1, 0, 0.5 }, { "icon", 0.27, 0.27, 0.5, 1 },
    { "bgActive", 0, 0.2, 0, 0 }, { "bgActive", 0.2, 0.17, 0, 1 },
    { "bgInactive", 0, 0.37, 1, 1 }, { "bgInactive", 0.37, 0.1, 1, 0 },
    { "bgGlow", 0, 0.17, 0, 1 }, { "bgGlow", 0.17, 0.4, 1, 0 },
}

local ROGUE_SPEND = {
    { "frameGlow", 0, 0.5, 1, 0 },
    { "icon", 0, 0.17, 1, 0 },
    { "fx", 0, 0.4, 1, 0 },
    { "bgActive", 0, 0.2, 1, 1 }, { "bgActive", 0.2, 0.17, 1, 0 },
    { "bgInactive", 0, 0.37, 0, 0 }, { "bgInactive", 0.37, 0.1, 0, 1 },
}

local DRUID_GAIN = {
    { "slash", 0, 0, 0, 1 },
    { "icon", 0, 0.1, 0, 0.5 }, { "icon", 0.47, 0.2, 0.5, 1 },
    { "ringGlow", 0, 0.27, 0, 1 }, { "ringGlow", 0.27, 0.47, 1, 0 },
    { "bgActive", 0, 0.27, 0, 0 }, { "bgActive", 0.27, 0.01, 0, 1 },
    { "bgInactive", 0, 0.27, 1, 1 }, { "bgInactive", 0.27, 0.01, 1, 0 },
    { "bgGlow", 0, 0.17, 0, 0 }, { "bgGlow", 0.17, 0.13, 0, 1 }, { "bgGlow", 0.3, 0.4, 1, 0 },
}

-- Retail leaves the lit socket up after a spend; the cross-fade makes an empty druid pip read as empty.
local DRUID_SPEND = {
    { "smoke", 0, 0.33, 1, 1 }, { "smoke", 0.33, 0.23, 1, 0 },
    { "ringGlow", 0, 0.43, 1, 1 }, { "ringGlow", 0.43, 0.23, 1, 0 },
    { "icon", 0, 0.2, 1, 0 },
    { "deplete", 0, 0.23, 1, 1 }, { "deplete", 0.23, 0.2, 1, 0 },
    { "bgActive", 0, 0.2, 1, 0 },
    { "bgInactive", 0, 0.2, 0, 1 },
}

local GEM_GAIN = {
    { "highlight", 0, GEM_HIGHLIGHT_IN, 0, 1 },
    { "shine", GEM_HIGHLIGHT_IN, GEM_SHINE_IN, 0, 1 },
    { "shine", GEM_HIGHLIGHT_IN + GEM_SHINE_IN, GEM_SHINE_OUT, 1, 0 },
}

-- Groups each track list by texture and records how long it runs.
local function Transition(tracks, flipbook, rise)
    local byKey, duration = {}, 0
    for _, track in ipairs(tracks) do
        byKey[track[1]] = byKey[track[1]] or {}
        table.insert(byKey[track[1]], track)
        duration = math.max(duration, track[2] + track[3])
    end
    if flipbook then duration = math.max(duration, flipbook[4]) end
    if rise then duration = math.max(duration, rise[2]) end
    return { byKey = byKey, duration = duration, flipbook = flipbook, rise = rise }
end

-- Flipbooks { columns, rows, frames, seconds }; the last cell is empty, so the slash ends invisible.
local ROGUE_FLIPBOOK = { 6, 3, 17, 0.57 }
local DRUID_FLIPBOOK = { 8, 3, 20, 1 }

local FAMILIES = {
    rogue = {
        file = ART .. "Retail", rects = RETAIL_RECTS, layers = ROGUE_LAYERS, flipbook = ROGUE_FLIPBOOK,
        gain = Transition(ROGUE_GAIN, ROGUE_FLIPBOOK), spend = Transition(ROGUE_SPEND),
    },
    druid = {
        file = ART .. "Retail", rects = RETAIL_RECTS, layers = DRUID_LAYERS, flipbook = DRUID_FLIPBOOK,
        gain = Transition(DRUID_GAIN, DRUID_FLIPBOOK), spend = Transition(DRUID_SPEND, nil, { 7, 0.56 }),
    },
    forever = {
        file = ART .. "Forever", rects = FOREVER_RECTS, layers = FOREVER_LAYERS, flipbook = ROGUE_FLIPBOOK,
        gain = Transition(ROGUE_GAIN, ROGUE_FLIPBOOK), spend = Transition(ROGUE_SPEND),
    },
}

local GEM_TRANSITION = Transition(GEM_GAIN)

-- =============================================================================
-- Module
-- =============================================================================

local ComboPoints = {
    initialized = false,
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule(KEY, ComboPoints,
        L["Combo Points"],
        L["Combo points as orbs under the player frame and/or gems around the target portrait."],
        { lifecyclePrefix = "ComboPoints" })
end

local bar, arc, editorBox
local views = {}
local parked
local previewing = false

local eventFrame = CreateFrame("Frame")
local driver = CreateFrame("Frame", nil, UIParent)
local holder = CreateFrame("Frame")
holder:Hide()

local function Cfg()
    return addon.db.profile.combopoints
end

local function PlayerClass()
    return select(2, UnitClass("player"))
end

-- "auto" follows the unit frame art: the bar with DragonUI's, Forever's arc with Forever's.
local function Resolve()
    local cfg = Cfg()
    local forever = UF.GetFrameStyle() == "forever"
    local location = cfg.location
    if location ~= "player" and location ~= "target" and location ~= "both" then
        location = forever and "target" or "player"
    end
    local style = cfg.style
    if style ~= "dragonui" and style ~= "forever" then
        style = forever and "forever" or "dragonui"
    end
    local onPlayer = (location == "player" or location == "both") and UF.IsEnabled("player")
    local onTarget = (location == "target" or location == "both") and UF.IsEnabled("target")
    return onPlayer, onTarget, style
end

local function CurrentUnit()
    return UnitHasVehicleUI("player") and "vehicle" or "player"
end

-- Rogues always, druids in cat form; a vehicle only shows the points it holds.
local function Eligible(unit)
    if unit ~= "player" then return false end
    local class = PlayerClass()
    return class == "ROGUE" or (class == "DRUID" and UnitPowerType("player") == POWER_ENERGY)
end

local function TrackAlpha(tracks, t)
    local current
    for i = 1, #tracks do
        local track = tracks[i]
        if track[2] <= t and (not current or track[2] >= current[2]) then
            current = track
        end
    end
    if not current then return 0 end
    local start, duration, from, to = current[2], current[3], current[4], current[5]
    if duration <= 0 or t >= start + duration then return to end
    return from + (to - from) * (t - start) / duration
end

local function SetRect(texture, rect)
    local x, y, w, h = rect[1], rect[2], rect[3], rect[4]
    texture:SetTexCoord(x / SHEET_W, (x + w) / SHEET_W, y / SHEET_H, (y + h) / SHEET_H)
end

-- =============================================================================
-- Player bar (pips)
-- =============================================================================

local function PipTexture(pip, key, onFx)
    local id = onFx and (key .. "+fx") or key
    local texture = pip.all[id]
    if not texture then
        texture = (onFx and pip.fx or pip):CreateTexture(nil, "ARTWORK")
        pip.all[id] = texture
    end
    return texture
end

local function SkinPip(pip, family)
    for _, texture in pairs(pip.all) do
        texture:Hide()
    end
    pip.tex = {}
    pip.layout = {}
    for _, layer in ipairs(family.layers) do
        local key, piece, w, h, x, y, drawLayer, onFx = unpack(layer)
        local texture = PipTexture(pip, key, onFx)
        texture:SetDrawLayer(drawLayer)
        texture:SetTexture(family.file)
        SetRect(texture, family.rects[piece])
        texture:SetSize(w, h)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", pip, "CENTER", x, y)
        texture:Show()
        pip.tex[key] = texture
        pip.layout[key] = { x = x, y = y, rect = family.rects[piece] }
    end
end

local function SnapPip(pip, full)
    for key, texture in pairs(pip.tex) do
        texture:SetAlpha(key == "shadow" and 1 or 0)
    end
    local smoke = pip.layout.smoke
    if smoke then
        pip.tex.smoke:SetPoint("CENTER", pip, "CENTER", smoke.x, smoke.y)
    end
    pip.tex[full and "bgActive" or "bgInactive"]:SetAlpha(1)
    if full then pip.tex.icon:SetAlpha(1) end
end

local function ResetPip(pip)
    for key, texture in pairs(pip.tex) do
        if key ~= "shadow" then texture:SetAlpha(0) end
    end
end

local function SetFlipbookCell(pip, flipbook, t)
    local slash, layout = pip.tex.slash, pip.layout.slash
    if not slash then return end
    local columns, rows, frames, seconds = flipbook[1], flipbook[2], flipbook[3], flipbook[4]
    local cell = min(frames - 1, floor(t / seconds * frames))
    local rect = layout.rect
    local w, h = rect[3] / columns, rect[4] / rows
    local x, y = rect[1] + (cell % columns) * w, rect[2] + floor(cell / columns) * h
    slash:SetTexCoord(x / SHEET_W, (x + w) / SHEET_W, y / SHEET_H, (y + h) / SHEET_H)
end

local function CreateBar()
    bar = CreateFrame("Frame", "DragonUIComboPointBar", PlayerFrame)
    bar:SetSize(MAX_POINTS * PIP_SIZE + (MAX_POINTS - 1) * PIP_SPACING, PIP_SIZE)
    bar:Hide()
    bar.elements = {}
    for i = 1, MAX_POINTS do
        local pip = CreateFrame("Frame", nil, bar)
        pip:SetSize(PIP_SIZE, PIP_SIZE)
        pip:SetPoint("LEFT", bar, "LEFT", (i - 1) * (PIP_SIZE + PIP_SPACING), 0)
        pip.fx = CreateFrame("Frame", nil, pip)
        pip.fx:SetAllPoints(pip)
        pip.all = {}
        pip.tex = {}
        bar.elements[i] = pip
    end
    bar.Snap = SnapPip
    bar.Reset = ResetPip
end

local function SkinBar(family)
    bar:SetFrameLevel(PlayerFrame:GetFrameLevel() + 5)
    for _, pip in ipairs(bar.elements) do
        pip:SetFrameLevel(bar:GetFrameLevel() + 1)
        pip.fx:SetFrameLevel(pip:GetFrameLevel() + 1)
        SkinPip(pip, family)
        pip.full = nil
        pip.anim = nil
    end
    bar.family = family
    bar.gain, bar.spend = family.gain, family.spend
end

-- =============================================================================
-- Player bar position (editor)
-- =============================================================================

-- A layout reset can drop the saved spot while the flag stays: without a spot the bar is attached.
local function Detached()
    local widgets = addon.db.profile.widgets
    local spot = widgets and widgets[KEY]
    return Cfg().detached and spot and spot.posX ~= nil and true or false
end

-- Moves the box onto UIParent's centre where it stands (it may sit on the bar), so its offsets are screen ones.
local function PinEditorBox()
    local x, y = editorBox:GetCenter()
    local cx, cy = UIParent:GetCenter()
    if not (x and cx) then return false end
    editorBox:ClearAllPoints()
    editorBox:SetPoint("CENTER", UIParent, "CENTER", x - cx, y - cy)
    return true
end

-- Under the player frame until moved in the editor; then it follows the editor box (widgets.combopoints).
local function PlaceBar()
    if not bar then return end
    bar:ClearAllPoints()
    if Detached() then
        -- Off the bar first: the saved spot is not applied in combat, and the box may still hang from the bar.
        PinEditorBox()
        addon.ApplyWidgetPositionFromDB(KEY, editorBox)
        bar:SetPoint("CENTER", editorBox, "CENTER", 0, 0)
    else
        local drop = PlayerClass() == "DRUID" and DRUID_BAR_DROP or 0
        bar:SetPoint("CENTER", PlayerFrame, "BOTTOM", BAR_X, BAR_Y - drop)
    end
end

-- The box is a UIParent child, the bar a PlayerFrame one: size it to the player frame's scale.
local function SyncEditorBox()
    if not Detached() then
        editorBox:ClearAllPoints()
        editorBox:SetPoint("CENTER", bar, "CENTER", 0, 0)
    end
    addon.SetEditorBoxScale(editorBox, PlayerFrame:GetEffectiveScale() / UIParent:GetEffectiveScale())
end

local function DetachBar()
    if PinEditorBox() then
        addon.SaveUIFramePosition(editorBox, "widgets", KEY)
        Cfg().detached = true
    end
    PlaceBar()
end

-- Attached, the box rides on the bar; turned around before the drag, the orbs follow from the first move.
local function GrabBar()
    if Detached() or not PinEditorBox() then return end
    bar:ClearAllPoints()
    bar:SetPoint("CENTER", editorBox, "CENTER", 0, 0)
end

-- =============================================================================
-- Target arc (gems)
-- =============================================================================

local function SnapGem(gem, full)
    gem.tex.highlight:SetAlpha(full and 1 or 0)
    gem.tex.shine:SetAlpha(0)
end

local function ResetGem(gem)
    gem.tex.highlight:SetAlpha(0)
    gem.tex.shine:SetAlpha(0)
end

-- ComboPointTemplate: gem, highlight and additive shine strips of one 32x16 file on a 12x12 frame.
local function CreateGem(parent)
    local gem = CreateFrame("Frame", nil, parent)
    gem:SetSize(12, 12)
    local point = gem:CreateTexture(nil, "BACKGROUND")
    point:SetTexture(GEM_TEXTURE)
    point:SetSize(12, 16)
    point:SetPoint("TOPLEFT")
    point:SetTexCoord(0, 0.375, 0, 1)
    local highlight = gem:CreateTexture(nil, "ARTWORK")
    highlight:SetTexture(GEM_TEXTURE)
    highlight:SetSize(8, 16)
    highlight:SetPoint("TOPLEFT", 2, 0)
    highlight:SetTexCoord(0.375, 0.5625, 0, 1)
    local shine = gem:CreateTexture(nil, "OVERLAY")
    shine:SetTexture(GEM_TEXTURE)
    shine:SetBlendMode("ADD")
    shine:SetSize(14, 16)
    shine:SetPoint("TOPLEFT", 0, 4)
    shine:SetTexCoord(0.5625, 1, 0, 1)
    gem.tex = { point = point, highlight = highlight, shine = shine }
    ResetGem(gem)
    return gem
end

local function CreateArc()
    arc = CreateFrame("Frame", "DragonUIComboPointArc", TargetFrame)
    arc:SetSize(1, 1)
    arc:Hide()
    arc.elements = {}
    for i = 1, MAX_POINTS do
        arc.elements[i] = CreateGem(arc)
    end
    arc.Snap = SnapGem
    arc.Reset = ResetGem
end

local function LayoutArc()
    -- The skin, not the texture: the target module may size its portrait after this runs at boot.
    local portrait = UF.GetFrameSkin().target.portrait
    local scale = (portrait and portrait.w or 54) / ARC_PORTRAIT
    arc:SetFrameStrata("MEDIUM")
    arc:ClearAllPoints()
    arc:SetPoint("CENTER", TargetFramePortrait, "CENTER", 0, 0)
    for i, gem in ipairs(arc.elements) do
        gem:ClearAllPoints()
        gem:SetPoint("CENTER", arc, "CENTER", ARC[i][1] * scale, ARC[i][2] * scale)
    end
    arc.gain, arc.spend = GEM_TRANSITION, nil
end

-- =============================================================================
-- Animation driver
-- =============================================================================

local function StepElement(view, element, now)
    local anim = element.anim
    local t = now - element.animStart
    if t >= anim.duration then
        element.anim = nil
        view.Snap(element, element.full)
        return false
    end
    for key, tracks in pairs(anim.byKey) do
        local texture = element.tex[key]
        if texture then texture:SetAlpha(TrackAlpha(tracks, t)) end
    end
    if anim.flipbook then SetFlipbookCell(element, anim.flipbook, t) end
    if anim.rise and element.tex.smoke then
        local smoke = element.layout.smoke
        element.tex.smoke:SetPoint("CENTER", element, "CENTER", smoke.x, smoke.y + anim.rise[1] * min(1, t / anim.rise[2]))
    end
    return true
end

local function Animating(view)
    for _, element in ipairs(view.elements) do
        if element.anim then return true end
    end
    return false
end

local function OnDriverUpdate()
    local now = GetTime()
    local busy = false
    for _, view in ipairs(views) do
        if view.fadeStart then
            local progress = (now - view.fadeStart) / FADE_IN
            if progress >= 1 then
                view.fadeStart = nil
                view:SetAlpha(1)
            else
                view:SetAlpha(progress)
                busy = true
            end
        end
        for _, element in ipairs(view.elements) do
            if element.anim and StepElement(view, element, now) then
                busy = true
            end
        end
        if view.hidePending and not Animating(view) then
            view.hidePending = nil
            view:Hide()
        end
    end
    if not busy then
        driver:SetScript("OnUpdate", nil)
    end
end

local function Wake()
    driver:SetScript("OnUpdate", OnDriverUpdate)
end

local function StartTransition(view, element, anim)
    view.Reset(element)
    element.anim = anim
    element.animStart = GetTime()
    -- Draw t = 0 now: the reset alone would blank a spent pip for one frame.
    StepElement(view, element, element.animStart)
    Wake()
end

-- =============================================================================
-- Update
-- =============================================================================

-- animate: only UNIT_COMBO_POINTS gains or spends; a new target, vehicle, form or option just shows the new count.
local function UpdateView(view, count, wanted, animate)
    local visible = view:IsShown() and not view.hidePending
    local colorblind = ENABLE_COLORBLIND_MODE == "1"
    for i, element in ipairs(view.elements) do
        local full = i <= count
        if element.full ~= full then
            local had = element.full
            element.full = full
            local anim = full and view.gain or view.spend
            if animate and visible and had ~= nil and anim then
                StartTransition(view, element, anim)
            else
                element.anim = nil
                view.Snap(element, full)
            end
        end
        element:SetShownCompat(full or not colorblind)
    end

    if wanted then
        view.hidePending = nil
        if not view:IsShown() then
            view:SetAlpha(0)
            view:Show()
            view.fadeStart = GetTime()
            Wake()
        end
    elseif view:IsShown() and not view.hidePending then
        if animate and Animating(view) then
            view.hidePending = true
            Wake()
        else
            view.fadeStart = nil
            view:Hide()
        end
    end
end

local function Update(animate)
    if not ComboPoints.applied then return end
    local unit = CurrentUnit()
    local count = GetComboPoints(unit, "target") or 0
    local wanted = count > 0 or (Eligible(unit) and not Cfg().hide_empty)
    for _, view in ipairs(views) do
        if view == bar and previewing then
            UpdateView(view, PREVIEW_POINTS, true, false)
        else
            UpdateView(view, count, wanted and (view ~= arc or UnitExists("target")), animate)
        end
    end
end

-- =============================================================================
-- Editor
-- =============================================================================

local function CreateEditor()
    editorBox = addon.CreateUIFrame(bar:GetWidth(), bar:GetHeight(), "ComboPoints")
    -- Before the stock handler's StartMoving: re-anchoring a frame mid-move breaks the drag.
    local startDrag = editorBox:GetScript("OnDragStart")
    editorBox:SetScript("OnDragStart", function(self, ...)
        GrabBar()
        if startDrag then return startDrag(self, ...) end
    end)
    editorBox:HookScript("OnDragStop", DetachBar)
    addon:RegisterEditableFrame({
        name = KEY,
        frame = editorBox,
        configPath = { "widgets", KEY },
        -- Other classes only get combo points in some vehicles, and those show at the saved spot.
        editorVisible = function()
            local class = PlayerClass()
            return ComboPoints.applied and bar.onPlayer and (class == "ROGUE" or class == "DRUID") or false
        end,
        -- A few lit orbs to place, whatever the current count or form.
        showTest = function()
            previewing = true
            SyncEditorBox()
            Update(false)
        end,
        hideTest = function()
            previewing = false
            PlaceBar()
            Update(false)
        end,
        onNudge = DetachBar,
        resetPosition = function()
            Cfg().detached = false
            PlaceBar()
            SyncEditorBox()
        end,
        isDefaultPosition = function()
            return not Detached()
        end,
        applyPosition = PlaceBar,
        module = ComboPoints,
    })
end

-- =============================================================================
-- Stock ComboFrame
-- =============================================================================

-- A hidden parent keeps it out of sight even when PlayerFrame_ToVehicleArt calls ComboFrame_Update directly.
local function ParkStock(park)
    if park and not parked then
        parked = {
            parent = ComboFrame:GetParent(),
            strata = ComboFrame:GetFrameStrata(),
            level = ComboFrame:GetFrameLevel(),
        }
        ComboFrame:SetParent(holder)
    elseif not park and parked then
        ComboFrame:SetParent(parked.parent)
        ComboFrame:SetFrameStrata(parked.strata)
        ComboFrame:SetFrameLevel(parked.level)
        parked = nil
    end
end

-- =============================================================================
-- Lifecycle
-- =============================================================================

local function OnEvent(_, event, unit)
    if event == "UNIT_COMBO_POINTS" then
        if unit == CurrentUnit() then Update(true) end
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" or event == "UNIT_DISPLAYPOWER" then
        if unit == "player" then Update(false) end
    else
        Update(false)
    end
end

local function ApplyNow()
    local onPlayer, onTarget, style = Resolve()
    if not bar then
        CreateBar()
        CreateEditor()
    end
    if not arc then CreateArc() end

    local wasOn = {}
    for _, view in ipairs(views) do wasOn[view] = true end
    views = {}
    bar.onPlayer = onPlayer
    if onPlayer then
        local family = FAMILIES[style == "forever" and "forever" or (PlayerClass() == "DRUID" and "druid" or "rogue")]
        if bar.family ~= family then SkinBar(family) end
        PlaceBar()
        table.insert(views, bar)
    end
    if onTarget then
        LayoutArc()
        table.insert(views, arc)
    end
    -- A re-apply leaves a view that stays on untouched; hiding it here made every refresh blink and fade back in.
    for _, view in ipairs({ bar, arc }) do
        if not ((view == bar and onPlayer) or (view == arc and onTarget)) or not wasOn[view] then
            view.hidePending, view.fadeStart = nil, nil
            view:SetAlpha(1)
            view:Hide()
            for _, element in ipairs(view.elements) do
                element.full, element.anim = nil, nil
            end
        end
    end

    ComboPoints.initialized = true
    ComboPoints.applied = #views > 0
    ParkStock(ComboPoints.applied)

    eventFrame:UnregisterAllEvents()
    if ComboPoints.applied then
        eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
        eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
        eventFrame:RegisterEvent("UNIT_COMBO_POINTS")
        eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
        eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
        eventFrame:RegisterEvent("UNIT_DISPLAYPOWER")
        eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
        eventFrame:SetScript("OnEvent", OnEvent)
        Update(false)
    end
end

local function RestoreNow()
    ComboPoints.applied = false
    eventFrame:UnregisterAllEvents()
    driver:SetScript("OnUpdate", nil)
    if bar then bar:Hide() end
    if arc then arc:Hide() end
    views = {}
    ParkStock(false)
end

-- Apply and restore share one combat-queue slot, so the last toggle made in combat is the one that lands.
function addon.ApplyComboPointsSystem()
    addon:SafeExecute(KEY, "apply", ApplyNow)
end

function addon.RestoreComboPointsSystem()
    addon:SafeExecute(KEY, "apply", RestoreNow)
end

function addon.RefreshComboPointsSystem()
    if addon:IsModuleEnabled(KEY) then
        addon.ApplyComboPointsSystem()
    else
        addon.RestoreComboPointsSystem()
    end
end
