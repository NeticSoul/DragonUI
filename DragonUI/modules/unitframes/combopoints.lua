-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Combo points: retail's orb bar under the player frame and/or small orbs on the target frame.

local addon = select(2, ...)
local L = addon.L
local UF = addon.UF

local KEY = "combopoints"
local ART = addon._dir .. "UnitFrames\\ComboPoints\\"
local MAX_POINTS = 5
local PIP_SIZE, PIP_SPACING = 20, 4
-- Bar centre on PlayerFrame's BOTTOM: the row DragonUI gives the DK runes.
local BAR_X, BAR_Y = 45, 15
-- In cat form the druid's mana bar takes that row, so their orbs sit lower.
local DRUID_BAR_DROP = 9
local POWER_ENERGY = 3
local PREVIEW_POINTS = 3
-- ComboFrame.lua's COMBOFRAME_FADE_IN and COMBOFRAME_FADE_OUT.
local FADE_IN, FADE_OUT = 0.3, 0.5
-- Forever's arc over the 54-unit portrait's top right, in degrees: 2 into its ring (26.5..30).
local ARC_FOREVER = { radius = 32.5, first = 92, step = -18 }
-- Blizzard's gems by angle on our smaller ring, clear of the raid mark on the portrait's top; higher over a level circle.
local ARC_VANILLA = { radius = 32.5, first = 48, step = -17, circleFirst = 58 }
-- Round a dragon: down the ring's right, filling upwards; above Forever's level circle when shown.
local ARC_DRAGON = { radius = 28.5, first = -50, step = 20, circleFirst = 0 }
-- An arc reaching past this angle runs over the raid mark on the portrait's top.
local RAID_MARK_ANGLE = 60
local ARC_PORTRAIT = 54

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

-- Half-size pieces for the target's small orbs, spaced so no mip mixes them (gen_combopoints_small.py).
local RETAIL_SMALL_RECTS = {
    rogue_slash     = { 0, 0, 258, 129 },
    druid_slash     = { 272, 0, 208, 123 },
    rogue_shadow    = { 0, 144, 25, 25 },
    rogue_bg        = { 40, 144, 20, 20 },
    rogue_bgdis     = { 72, 144, 20, 20 },
    rogue_frameglow = { 104, 144, 23, 23 },
    rogue_icon      = { 136, 144, 14, 15 },
    rogue_fx        = { 160, 144, 14, 14 },
    druid_shadow    = { 184, 144, 25, 25 },
    druid_bg        = { 224, 144, 20, 20 },
    druid_bgdis     = { 256, 144, 20, 20 },
    druid_ringglow  = { 288, 144, 23, 23 },
    druid_icon      = { 320, 144, 14, 14 },
    druid_deplete   = { 344, 144, 16, 15 },
    druid_bgglow    = { 368, 144, 36, 36 },
    druid_smoke     = { 416, 144, 22, 48 },
}

local FOREVER_SMALL_RECTS = {
    rogue_slash     = { 0, 0, 258, 129 },
    rogue_shadow    = { 0, 144, 25, 25 },
    rogue_bg        = { 40, 144, 22, 22 },
    rogue_bgdis     = { 72, 144, 22, 22 },
    rogue_frameglow = { 104, 144, 22, 22 },
    rogue_icon      = { 136, 144, 14, 14 },
    rogue_fx        = { 160, 144, 14, 14 },
}

local RETAIL_ART = { file = ART .. "Retail", rects = RETAIL_RECTS, w = 1024, h = 512 }
local RETAIL_SMALL_ART = { file = ART .. "Retail-Small", rects = RETAIL_SMALL_RECTS, w = 512, h = 256 }
local FOREVER_ART = { file = ART .. "Forever", rects = FOREVER_RECTS, w = 1024, h = 512 }
local FOREVER_SMALL_ART = { file = ART .. "Forever-Small", rects = FOREVER_SMALL_RECTS, w = 512, h = 256 }

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
        art = RETAIL_ART, small = RETAIL_SMALL_ART, layers = ROGUE_LAYERS, flipbook = ROGUE_FLIPBOOK,
        gain = Transition(ROGUE_GAIN, ROGUE_FLIPBOOK), spend = Transition(ROGUE_SPEND),
    },
    druid = {
        art = RETAIL_ART, small = RETAIL_SMALL_ART, layers = DRUID_LAYERS, flipbook = DRUID_FLIPBOOK,
        gain = Transition(DRUID_GAIN, DRUID_FLIPBOOK), spend = Transition(DRUID_SPEND, nil, { 7, 0.56 }),
    },
    forever = {
        art = FOREVER_ART, small = FOREVER_SMALL_ART, layers = FOREVER_LAYERS, flipbook = ROGUE_FLIPBOOK,
        gain = Transition(ROGUE_GAIN, ROGUE_FLIPBOOK), spend = Transition(ROGUE_SPEND),
    },
}

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
        L["Combo points as orbs under the player frame and/or on the target frame."],
        { lifecyclePrefix = "ComboPoints" })
end

local bar, arc, column, editorBox
local arcInUse, orbsCanShow, arcOverPortrait = false, false, false
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

-- The target's PvP emblem steps past the column only while it is up (fading out included).
function UF.ComboOnCompactTarget()
    return column ~= nil and column:IsShown() and true or false
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

local function SetRect(texture, art, x, y, w, h)
    texture:SetTexCoord(x / art.w, (x + w) / art.w, y / art.h, (y + h) / art.h)
end

-- =============================================================================
-- Pips (player bar, target arc and column)
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

local function SkinPip(pip, family, art)
    for _, texture in pairs(pip.all) do
        texture:Hide()
    end
    pip.tex = {}
    pip.layout = {}
    pip.art = art
    for _, layer in ipairs(family.layers) do
        local key, piece, w, h, x, y, drawLayer, onFx = unpack(layer)
        local rect = art.rects[piece]
        local texture = PipTexture(pip, key, onFx)
        texture:SetDrawLayer(drawLayer)
        texture:SetTexture(art.file)
        SetRect(texture, art, unpack(rect))
        texture:SetSize(w, h)
        texture:ClearAllPoints()
        texture:SetPoint("CENTER", pip, "CENTER", x, y)
        texture:Show()
        pip.tex[key] = texture
        pip.layout[key] = { x = x, y = y, rect = rect }
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
    SetRect(slash, pip.art, rect[1] + (cell % columns) * w, rect[2] + floor(cell / columns) * h, w, h)
end

-- The caller lays the pips out: the player's row, the target's arc or its column.
local function CreatePips(name, parent)
    local view = CreateFrame("Frame", name, parent)
    view:Hide()
    view.elements = {}
    for i = 1, MAX_POINTS do
        local pip = CreateFrame("Frame", nil, view)
        pip:SetSize(PIP_SIZE, PIP_SIZE)
        pip.fx = CreateFrame("Frame", nil, pip)
        pip.fx:SetAllPoints(pip)
        pip.all = {}
        pip.tex = {}
        view.elements[i] = pip
    end
    view.Snap = SnapPip
    view.Reset = ResetPip
    return view
end

local function CreateBar()
    bar = CreatePips("DragonUIComboPointBar", PlayerFrame)
    bar:SetSize(MAX_POINTS * PIP_SIZE + (MAX_POINTS - 1) * PIP_SPACING, PIP_SIZE)
    for i, pip in ipairs(bar.elements) do
        pip:SetPoint("LEFT", bar, "LEFT", (i - 1) * (PIP_SIZE + PIP_SPACING), 0)
    end
end

-- small: the target's orbs, drawn at UF.COMPACT.target.combo.scale from the half-size sheet.
local function SkinPips(view, family, level, small)
    local art = small and family.small or family.art
    if view.family == family and view.art == art then return end
    view:SetFrameLevel(level)
    for _, pip in ipairs(view.elements) do
        pip:SetFrameLevel(view:GetFrameLevel() + 1)
        pip.fx:SetFrameLevel(pip:GetFrameLevel() + 1)
        SkinPip(pip, family, art)
        -- Small orbs stand close: a shadow dropped under one would darken its neighbour.
        if small then
            pip.tex.shadow:SetPoint("CENTER", pip, "CENTER", 0, 0)
        end
        pip.full = nil
        pip.anim = nil
    end
    view.family, view.art = family, art
    view.gain, view.spend = family.gain, family.spend
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
-- Target orbs: Forever's arc round the portrait, or a column off a portrait-off frame's end
-- =============================================================================

local function SmallScale()
    return UF.COMPACT.target.combo.scale
end

local function CreateArc()
    arc = CreatePips("DragonUIComboPointArc", TargetFrame)
    arc:SetSize(1, 1)
    arc:SetScale(SmallScale())
    arc:SetFrameStrata("MEDIUM")
end

local function CreateColumn()
    local step = UF.COMPACT.target.combo.pitch / SmallScale()
    column = CreatePips("DragonUIComboPointColumn", TargetFrame)
    column:SetScale(SmallScale())
    column:SetSize(PIP_SIZE, PIP_SIZE + (MAX_POINTS - 1) * step)
    -- Point 1 at the bottom: the column fills upwards.
    for i, pip in ipairs(column.elements) do
        pip:SetPoint("BOTTOM", column, "BOTTOM", 0, (i - 1) * step)
    end
    -- The target's PvP emblem steps aside while the column is up and comes back when it goes.
    local function MoveEmblem()
        if UF.PlaceTargetPvPIcon then UF.PlaceTargetPvPIcon() end
    end
    hooksecurefunc(column, "Show", MoveEmblem)
    hooksecurefunc(column, "Hide", MoveEmblem)
end

local function LayoutColumn(family)
    SkinPips(column, family, TargetFrame:GetFrameLevel() + 1, true)
    -- target_style.lua moves the slot past the frame's end, its dragon or its level circle, down on the bottom rim.
    column:ClearAllPoints()
    column:SetPoint("BOTTOM", UF.GetComboSlot(), "CENTER", 0, 0)
end

local function ArcSpot()
    local elite = _G.DragonUI_TargetElite
    if elite and elite:IsShown() then return ARC_DRAGON end
    return UF.GetFrameStyle() == "forever" and ARC_FOREVER or ARC_VANILLA
end

local function ArcFirst(spot)
    return spot.circleFirst and UF.GetLevelSpot("target") and spot.circleFirst or spot.first
end

-- The raid mark steps aside while orbs can show on an arc that reaches it.
local function SyncRaidMark()
    local spot = ArcSpot()
    local first = ArcFirst(spot)
    local top = math.max(first, first + (MAX_POINTS - 1) * spot.step)
    local over = not not (arcInUse and orbsCanShow and top > RAID_MARK_ANGLE)
    if over ~= arcOverPortrait then
        arcOverPortrait = over
        if UF.PlaceTargetRaidMark then UF.PlaceTargetRaidMark() end
    end
end

function UF.ComboArcOverPortrait()
    return arcOverPortrait
end

-- Over the portrait's top-right ring, or bottom up its right side round a dragon.
local function PlaceArc()
    local spot = ArcSpot()
    local first = ArcFirst(spot)
    -- The skin, not the texture: the target module may size its portrait after this runs at boot.
    local portrait = UF.GetFrameSkin().target.portrait
    local radius = spot.radius * (portrait and portrait.w or ARC_PORTRAIT) / ARC_PORTRAIT / SmallScale()
    for i, pip in ipairs(arc.elements) do
        local angle = math.rad(first + (i - 1) * spot.step)
        pip:ClearAllPoints()
        pip:SetPoint("CENTER", arc, "CENTER", radius * math.cos(angle), radius * math.sin(angle))
    end
end

local function LayoutArc(family)
    SkinPips(arc, family, TargetFrame:GetFrameLevel() + 1, true)
    arc:ClearAllPoints()
    arc:SetPoint("CENTER", TargetFramePortrait, "CENTER", 0, 0)
    PlaceArc()
end

-- target_style.lua calls this whenever the target's dragon shows or goes.
function UF.OnTargetDragon()
    if arc and arc.art then PlaceArc() end
    SyncRaidMark()
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
        if view.fadeOutStart then
            local progress = (now - view.fadeOutStart) / FADE_OUT
            if progress >= 1 then
                view.fadeOutStart = nil
                view:Hide()
                -- Out of sight, the spent orbs take their empty look for the next time.
                for _, element in ipairs(view.elements) do
                    element.anim = nil
                    view.Snap(element, element.full)
                end
            else
                view:SetAlpha(1 - progress)
                busy = true
            end
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
    local visible = view:IsShown() and not view.fadeOutStart
    -- Spending the last points fades the view out as it stands, without emptying each orb first.
    local fadeOut = animate and visible and not wanted
    local colorblind = ENABLE_COLORBLIND_MODE == "1"
    for i, element in ipairs(view.elements) do
        local full = i <= count
        if element.full ~= full then
            local had = element.full
            element.full = full
            local anim = full and view.gain or view.spend
            if fadeOut then
                -- Left as it stands; OnDriverUpdate empties it once hidden.
            elseif animate and visible and had ~= nil and anim then
                StartTransition(view, element, anim)
            else
                element.anim = nil
                view.Snap(element, full)
            end
        end
        if not fadeOut then
            element:SetShownCompat(full or not colorblind)
        end
    end

    if wanted then
        if view.fadeOutStart then
            -- Points back mid-fade: the orbs show the count and fade back in from where they stand.
            view.fadeOutStart = nil
            for _, element in ipairs(view.elements) do
                element.anim = nil
                view.Snap(element, element.full)
            end
            view.fadeStart = GetTime() - view:GetAlpha() * FADE_IN
            Wake()
        elseif not view:IsShown() then
            view:SetAlpha(0)
            view:Show()
            view.fadeStart = GetTime()
            Wake()
        end
    elseif view:IsShown() and not view.fadeOutStart then
        if fadeOut then
            -- From wherever a fade-in left it.
            view.fadeOutStart = GetTime() - (1 - view:GetAlpha()) * FADE_OUT
            view.fadeStart = nil
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
    -- Points only build on what can be attacked: the target's orbs never show empty on yourself or a friend.
    local attackable = UnitCanAttack(unit, "target") and true or false
    local onTarget = count > 0 or (wanted and attackable)
    local exists = UnitExists("target") and true or false
    -- Not hide_empty's call: stepping back at every finisher would make the raid mark hop through a fight.
    orbsCanShow = exists and (count > 0 or (Eligible(unit) and attackable))
    SyncRaidMark()
    for _, view in ipairs(views) do
        if view == bar and previewing then
            UpdateView(view, PREVIEW_POINTS, true, false)
        elseif view == bar then
            UpdateView(view, count, wanted, animate)
        else
            UpdateView(view, count, onTarget and exists, animate)
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
    elseif event == "UNIT_FACTION" then
        -- A duel or a mind control turns the target attackable or not.
        if unit == "target" then Update(false) end
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
    if not column then CreateColumn() end

    local wasOn = {}
    for _, view in ipairs(views) do wasOn[view] = true end
    views = {}
    bar.onPlayer = onPlayer
    local family = FAMILIES[style == "forever" and "forever" or (PlayerClass() == "DRUID" and "druid" or "rogue")]
    if onPlayer then
        SkinPips(bar, family, PlayerFrame:GetFrameLevel() + 5)
        PlaceBar()
        table.insert(views, bar)
    end
    local onColumn = onTarget and UF.IsCompact("target")
    arcInUse = onTarget and not onColumn
    SyncRaidMark()
    if onColumn then
        LayoutColumn(family)
        table.insert(views, column)
    elseif onTarget then
        LayoutArc(family)
        table.insert(views, arc)
    end
    local wanted = { [bar] = onPlayer, [arc] = onTarget and not onColumn, [column] = onColumn }
    -- A re-apply leaves a view that stays on untouched; hiding it here made every refresh blink and fade back in.
    for _, view in ipairs({ bar, arc, column }) do
        if not wanted[view] or not wasOn[view] then
            view.fadeOutStart, view.fadeStart = nil, nil
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
        eventFrame:RegisterEvent("UNIT_FACTION")
        eventFrame:SetScript("OnEvent", OnEvent)
        Update(false)
    end
end

local function RestoreNow()
    ComboPoints.applied = false
    arcInUse = false
    SyncRaidMark()
    eventFrame:UnregisterAllEvents()
    driver:SetScript("OnUpdate", nil)
    if bar then bar:Hide() end
    if arc then arc:Hide() end
    if column then column:Hide() end
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

-- The orb sheets are TGAs (~30 ms first draw for the big one), else paid on the first point mid-fight.
addon:RegisterTextureWarmup(function()
    local class = PlayerClass()
    if not ComboPoints.applied or (class ~= "ROGUE" and class ~= "DRUID") then
        return nil
    end
    local files = {}
    for _, view in ipairs(views) do
        if view.art then files[#files + 1] = view.art.file end
    end
    return files
end)
