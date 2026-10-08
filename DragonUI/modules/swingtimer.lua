-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Swing timers as Forever ships them: one bar per hand (main, off, ranged), timed by LibSwingTimer-1.0.

local addon = select(2, ...)
local L = addon.L

local KEY = "swingtimer"
local ART = addon._dir .. "SwingTimer\\"
local FRAME_TEXTURE, BG_TEXTURE, SHEET_TEXTURE = ART .. "frame", ART .. "bg", ART .. "sheet"

-- Forever's 45-unit action buttons are ours at 36 drawn at 0.9: its HUD maps onto ours at 0.72.
local FOREVER_SCALE = 0.72
-- Forever's 213-852 by 15-60 range and 426x30 default, converted to our units.
local MIN_WIDTH, MAX_WIDTH, MIN_HEIGHT, MAX_HEIGHT = 153, 613, 11, 43
local DEFAULT_WIDTH, DEFAULT_HEIGHT = 307, 22
local DEFAULT_SCALE = 100
-- Art is laid out in Forever units: the StatusBar sits 5 in from the sides, 4 from top and bottom.
local FOREVER_HEIGHT = 30
local INSET_X, INSET_Y = 5, 4
local LABEL_INSET = 10
local SHADOW_WIDTH = 171
local PIP_WIDTH, PIP_HEIGHT = 5, 27
local OUT_OF_RANGE_ALPHA = 0.4
local PREVIEW_PROGRESS = 0.6

-- frame.blp 512x32: 16 px ends, 8 px edges; at the default height Forever draws one texel per unit.
local FRAME_W, FRAME_H = 512, 32
local SLICE_X, SLICE_Y = { 1, 17, 411, 427 }, { 1, 9, 23, 31 }
local CORNER_W, CORNER_H = 16, 8
-- sheet.blp 512x128: three 418x22 px fills, the label shadow and the pip.
local SHEET_W, SHEET_H = 512, 128
local FILL_LEFT, FILL_PIXELS, FILL_ROWS = 1, 418, 22

local BARS = {
    { hand = "mainhand", frameName = "SwingTimerMainHand", fillTop = 1, label = INVTYPE_WEAPONMAINHAND, previewSpeed = 2.6 },
    { hand = "offhand", frameName = "SwingTimerOffHand", fillTop = 33, label = INVTYPE_WEAPONOFFHAND, previewSpeed = 1.8 },
    { hand = "ranged", frameName = "SwingTimerRanged", fillTop = 65, label = INVTYPE_RANGED, previewSpeed = 2.9 },
}

local SwingTimer = {
    initialized = false,
    applied = false,
}

if addon.RegisterModule then
    addon:RegisterModule(KEY, SwingTimer,
        L["Swing Timer"],
        L["Show a bar with the time left until each weapon's next swing."],
        { lifecyclePrefix = "SwingTimer" })
end

local bars, barsByHand = {}, {}
local inCombat = false
local screenHeight
local callbacksRegistered = false
local eventFrame = CreateFrame("Frame")
local callbackOwner = {}

local floor, ceil, max = math.floor, math.ceil, math.max
local GetTime = GetTime

local function Lib()
    return LibStub and LibStub("LibSwingTimer-1.0", true)
end

local function Cfg(bar)
    return addon.db.profile.swingtimer[bar.def.hand]
end

local function Clamp(value, low, high, fallback)
    value = tonumber(value) or fallback
    if value < low then return low end
    if value > high then return high end
    return value
end

local function SetShown(region, shown)
    if shown then region:Show() else region:Hide() end
end

local function EditorActive()
    return addon.EditorMode and addon.EditorMode:IsActive() and true or false
end

local function RefreshScreenHeight()
    screenHeight = tonumber((GetCVar("gxResolution") or ""):match("%d+x(%d+)"))
end

-- Out of range dims the whole bar, as Forever does; the combat fade multiplies on top.
local function ApplyAlpha(bar)
    local range = bar.outOfRange and OUT_OF_RANGE_ALPHA or 1
    bar.frame:SetAlpha((bar.opacity or 1) * range * bar.fade)
end

-- =============================================================================
-- Frames
-- =============================================================================

-- The middle strips sample texel centres so the filter does not pull in the neighbouring slice.
local function SliceCoords(edges, index, size)
    local from, to = edges[index], edges[index + 1]
    if index == 2 then from, to = from + 0.5, to - 0.5 end
    return from / size, to / size
end

local function Between(texture, from, fromPoint, to, toPoint)
    texture:SetPoint("TOPLEFT", from, fromPoint, 0, 0)
    texture:SetPoint("BOTTOMRIGHT", to, toPoint, 0, 0)
end

-- Eight pieces (the centre is transparent): corners keep their size, the edges between them stretch.
local function CreateBorder(parent)
    local pieces, list = {}, {}
    for row = 1, 3 do
        pieces[row] = {}
        for column = 1, 3 do
            if row ~= 2 or column ~= 2 then
                local left, right = SliceCoords(SLICE_X, column, FRAME_W)
                local top, bottom = SliceCoords(SLICE_Y, row, FRAME_H)
                local texture = parent:CreateTexture(nil, "BORDER")
                texture:SetTexture(FRAME_TEXTURE)
                texture:SetTexCoord(left, right, top, bottom)
                pieces[row][column] = texture
                list[#list + 1] = texture
            end
        end
    end

    local topLeft, topRight, bottomLeft, bottomRight = pieces[1][1], pieces[1][3], pieces[3][1], pieces[3][3]
    topLeft:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
    topRight:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
    bottomLeft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
    bottomRight:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
    Between(pieces[1][2], topLeft, "TOPRIGHT", topRight, "BOTTOMLEFT")
    Between(pieces[3][2], bottomLeft, "TOPRIGHT", bottomRight, "BOTTOMLEFT")
    Between(pieces[2][1], topLeft, "BOTTOMLEFT", bottomLeft, "TOPRIGHT")
    Between(pieces[2][3], topRight, "BOTTOMLEFT", bottomRight, "TOPRIGHT")
    return list, { topLeft, topRight, bottomLeft, bottomRight }
end

-- Shorter than the default, the ends shrink with the bar like Forever's stretched frame; taller, they keep their size.
local function LayoutBorder(corners, height)
    local shrink = math.min(1, height / FOREVER_HEIGHT)
    for _, corner in ipairs(corners) do
        corner:SetSize(CORNER_W * shrink, CORNER_H * shrink)
    end
end

local function CreateLabel(parent, point, x)
    local text = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    text:SetPoint(point, parent, point, x, 0)
    return text
end

local function CreateBar(def)
    local bar = { def = def, widget = KEY .. "_" .. def.hand, fade = 1 }
    bar.setFade = function(value)
        bar.fade = value
        ApplyAlpha(bar)
    end
    bar.anchor = addon.CreateUIFrame(DEFAULT_WIDTH, DEFAULT_HEIGHT, def.frameName)

    local frame = CreateFrame("Frame", "DragonUI_" .. def.frameName .. "Bar", UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:SetPoint("TOPLEFT", bar.anchor, "TOPLEFT", 0, 0)
    frame:Hide()
    frame.swingBar = bar
    bar.frame = frame

    bar.background = frame:CreateTexture(nil, "BACKGROUND")
    bar.background:SetTexture(BG_TEXTURE)
    bar.background:SetTexCoord(1 / FRAME_W, 423 / FRAME_W, 1 / FRAME_H, 27 / FRAME_H)
    bar.background:SetAllPoints(frame)
    bar.border, bar.corners = CreateBorder(frame)

    -- A child frame, so everything on the bar draws over the border like Forever's StatusBar.
    local holder = CreateFrame("Frame", nil, frame)
    holder:SetPoint("TOPLEFT", frame, "TOPLEFT", INSET_X, -INSET_Y)
    holder:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -INSET_X, INSET_Y)
    bar.holder = holder

    bar.fill = holder:CreateTexture(nil, "BACKGROUND")
    bar.fill:SetTexture(SHEET_TEXTURE)
    bar.fill:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    bar.fill:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    bar.fill:Hide()
    bar.fillTop = def.fillTop / SHEET_H
    bar.fillBottom = (def.fillTop + FILL_ROWS) / SHEET_H

    bar.shadow = holder:CreateTexture(nil, "BORDER")
    bar.shadow:SetTexture(SHEET_TEXTURE)
    bar.shadow:SetTexCoord(1 / SHEET_W, 172 / SHEET_W, 97 / SHEET_H, 118 / SHEET_H)
    bar.shadow:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    bar.shadow:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 0)
    bar.shadow:SetWidth(SHADOW_WIDTH)

    bar.pip = holder:CreateTexture(nil, "ARTWORK")
    bar.pip:SetTexture(SHEET_TEXTURE)
    bar.pip:SetTexCoord(449 / SHEET_W, 459 / SHEET_W, 1 / SHEET_H, 55 / SHEET_H)
    bar.pip:SetSize(PIP_WIDTH, PIP_HEIGHT)
    bar.pip:Hide()

    bar.title = CreateLabel(holder, "LEFT", LABEL_INSET)
    bar.title:SetText(def.label or "")
    bar.time = CreateLabel(holder, "RIGHT", -LABEL_INSET)
    bar.time:SetText("0.0")

    bars[#bars + 1] = bar
    barsByHand[def.hand] = bar
    return bar
end

-- =============================================================================
-- Drawing
-- =============================================================================

-- 3.3.5a has no pixel snapping: at fractional offsets the thin pip shimmers, so it sits on whole pixels.
local function PlacePip(bar, right)
    local left = bar.holder:GetLeft()
    local pipWidth = PIP_WIDTH
    if left and screenHeight then
        local perUnit = bar.holder:GetEffectiveScale() * screenHeight / 768
        local pixel = floor((left + right) * perUnit + 0.5)
        local first, last = ceil(left * perUnit), floor((left + bar.innerWidth) * perUnit)
        if pixel < first then pixel = first elseif pixel > last then pixel = last end
        right = pixel / perUnit - left
        pipWidth = max(1, floor(PIP_WIDTH * perUnit + 0.5)) / perUnit
    end
    if pipWidth ~= bar.pipWidth then
        bar.pipWidth = pipWidth
        bar.pip:SetWidth(pipWidth)
    end
    bar.pip:SetPoint("RIGHT", bar.holder, "LEFT", right, 0)
    return right - pipWidth
end

-- Cropped by texcoords so the grain stays put; it stops at the pip, whose soft edges would show that grain.
local function Draw(bar, progress, remaining)
    local width = PlacePip(bar, bar.innerWidth * progress)
    if width >= 0.5 then
        local right = FILL_LEFT + FILL_PIXELS * width / bar.innerWidth
        bar.fill:SetWidth(width)
        bar.fill:SetTexCoord(FILL_LEFT / SHEET_W, right / SHEET_W, bar.fillTop, bar.fillBottom)
        bar.fill:Show()
    else
        bar.fill:Hide()
    end

    local tenths = floor(remaining * 10 + 0.5)
    if tenths ~= bar.tenths then
        bar.tenths = tenths
        bar.time:SetFormattedText("%.1f", tenths / 10)
    end
end

local function Clear(bar)
    bar.start, bar.duration, bar.pausedAt = nil, nil, nil
    bar.frame:SetScript("OnUpdate", nil)
    bar.fill:Hide()
    bar.pip:Hide()
    bar.tenths = 0
    bar.time:SetText("0.0")
end

local function OnUpdate(frame)
    local bar = frame.swingBar
    local remaining = bar.start + bar.duration - (bar.pausedAt or GetTime())
    if remaining <= 0 then
        Clear(bar)
        return
    end
    Draw(bar, 1 - remaining / bar.duration, remaining)
end

local function DrawPreview(bar)
    local lib = Lib()
    local speed = lib and lib:GetSpeed(bar.def.hand) or bar.def.previewSpeed
    bar.pip:Show()
    Draw(bar, PREVIEW_PROGRESS, speed * (1 - PREVIEW_PROGRESS))
end

local function Sync(bar)
    if bar.previewing then return end

    local lib = Lib()
    local start, duration, pausedAt
    if lib then start, duration, pausedAt = lib:GetSwing(bar.def.hand) end
    if start and duration and duration > 0 and start + duration > (pausedAt or GetTime()) then
        bar.start, bar.duration, bar.pausedAt = start, duration, pausedAt
        bar.pip:Show()
        bar.frame:SetScript("OnUpdate", OnUpdate)
        OnUpdate(bar.frame)
    else
        Clear(bar)
    end
end

-- Out of range also turns the text red, as Forever does; the editor preview never dims.
local function ApplyRange(bar)
    local lib = Lib()
    bar.outOfRange = not bar.previewing and lib and lib:IsInRange(bar.def.hand) == false
    ApplyAlpha(bar)
    local color = bar.outOfRange and RED_FONT_COLOR or HIGHLIGHT_FONT_COLOR
    bar.title:SetTextColor(color.r, color.g, color.b)
    bar.time:SetTextColor(color.r, color.g, color.b)
end

local function Layout(bar)
    local cfg = Cfg(bar)
    local width = Clamp(cfg.width, MIN_WIDTH, MAX_WIDTH, DEFAULT_WIDTH)
    local height = Clamp(cfg.height, MIN_HEIGHT, MAX_HEIGHT, DEFAULT_HEIGHT)
    local scale = Clamp(cfg.scale, 50, 200, DEFAULT_SCALE) / 100
    local artWidth, artHeight = width / FOREVER_SCALE, height / FOREVER_SCALE

    bar.frame:SetSize(artWidth, artHeight)
    LayoutBorder(bar.corners, artHeight)
    bar.frame:SetScale(scale * FOREVER_SCALE)
    bar.anchor:SetSize(width * scale, height * scale)
    bar.innerWidth = artWidth - 2 * INSET_X
    bar.opacity = Clamp(cfg.opacity, 50, 100, 100) / 100

    local showTitle = cfg.show_title ~= false
    SetShown(bar.title, showTitle)
    SetShown(bar.shadow, showTitle)
    SetShown(bar.time, cfg.show_time ~= false)
    ApplyRange(bar)

    if bar.previewing then
        DrawPreview(bar)
    elseif bar.start then
        OnUpdate(bar.frame)
    end
end

local function ApplyPosition(bar)
    if EditorActive() and bar.anchor:GetNumPoints() > 0 then return end

    local widgets = addon.db.profile.widgets
    local cfg = widgets and widgets[bar.widget] or addon.defaults.profile.widgets[bar.widget]

    bar.anchor:ClearAllPoints()
    bar.anchor:SetPoint(cfg.anchor, UIParent, cfg.anchor, cfg.posX, cfg.posY)
end

-- =============================================================================
-- Shown state and events
-- =============================================================================

local function ShouldShow(bar)
    if not SwingTimer.applied then return false end
    if bar.previewing then return true end

    local lib = Lib()
    if not (lib and lib:HasWeapon(bar.def.hand)) then return false end

    local mode = Cfg(bar).visibility
    if mode == "combat" then return inCombat end
    return mode ~= "hidden"
end

-- animate: only entering and leaving combat fade; weapons, the editor and settings switch at once.
local function UpdateShownState(animate)
    for _, bar in ipairs(bars) do
        addon.SetShownFaded(bar.frame, ShouldShow(bar), animate, bar.setFade)
    end
end

local function OnWeapons()
    UpdateShownState(false)
end

local function OnSwing(_, hand)
    local bar = barsByHand[hand]
    if bar and bar.frame:IsShown() then Sync(bar) end
end

local function OnStop(_, hand)
    local bar = barsByHand[hand]
    if bar and not bar.previewing then Clear(bar) end
end

local function OnRange(_, hand)
    local bar = barsByHand[hand]
    if bar then ApplyRange(bar) end
end

-- The library stays dormant while nothing listens, so hidden bars cost nothing.
local function UpdateCallbacks()
    local lib = Lib()
    if not lib then return end

    local wanted = false
    if SwingTimer.applied then
        for _, bar in ipairs(bars) do
            if Cfg(bar).visibility ~= "hidden" then wanted = true end
        end
    end
    if wanted == callbacksRegistered then return end

    callbacksRegistered = wanted
    if wanted then
        lib.RegisterCallback(callbackOwner, "SWING_START", OnSwing)
        lib.RegisterCallback(callbackOwner, "SWING_UPDATE", OnSwing)
        lib.RegisterCallback(callbackOwner, "SWING_STOP", OnStop)
        lib.RegisterCallback(callbackOwner, "SWING_RANGE", OnRange)
        lib.RegisterCallback(callbackOwner, "SWING_WEAPONS", OnWeapons)
    else
        lib.UnregisterAllCallbacks(callbackOwner)
    end
end

eventFrame:SetScript("OnEvent", function(_, event)
    if event == "DISPLAY_SIZE_CHANGED" then
        RefreshScreenHeight()
        return
    end
    if event == "PLAYER_REGEN_DISABLED" then
        inCombat = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        inCombat = false
    end
    UpdateShownState(event ~= "PLAYER_ENTERING_WORLD")
end)

-- =============================================================================
-- Editor
-- =============================================================================

local function StartPreview(bar)
    bar.previewing = true
    bar.frame:SetScript("OnUpdate", nil)
    UpdateShownState()
    Layout(bar)
end

local function StopPreview(bar)
    bar.previewing = false
    if not SwingTimer.applied then return end

    ApplyRange(bar)
    UpdateShownState()
    if bar.frame:IsShown() then Sync(bar) else Clear(bar) end
end

local function CreateEditorFrame(bar)
    addon:RegisterEditableFrame({
        name = bar.widget,
        frame = bar.anchor,
        configPath = { "widgets", bar.widget },
        editorVisible = function()
            return addon:IsModuleEnabled(KEY)
        end,
        showTest = function() StartPreview(bar) end,
        hideTest = function() StopPreview(bar) end,
        onHide = function()
            ApplyPosition(bar)
            if SwingTimer.applied then
                Layout(bar)
                UpdateShownState()
            end
        end,
        module = SwingTimer,
    })
end

local function DarkModeChrome()
    local textures = {}
    for _, bar in ipairs(bars) do
        textures[#textures + 1] = bar.background
        for _, piece in ipairs(bar.border) do textures[#textures + 1] = piece end
    end
    return textures
end

-- =============================================================================
-- Lifecycle
-- =============================================================================

function addon.ApplySwingTimerSystem()
    if #bars == 0 then
        for _, def in ipairs(BARS) do
            local bar = CreateBar(def)
            bar.frame:SetScript("OnShow", function()
                ApplyRange(bar)
                Sync(bar)
            end)
            CreateEditorFrame(bar)
        end
        if addon.RegisterDarkModeChrome then addon.RegisterDarkModeChrome(DarkModeChrome) end
    end

    SwingTimer.initialized = true
    SwingTimer.applied = true
    inCombat = UnitAffectingCombat("player") and true or false
    RefreshScreenHeight()

    eventFrame:UnregisterAllEvents()
    eventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")

    UpdateCallbacks()
    for _, bar in ipairs(bars) do
        ApplyPosition(bar)
        Layout(bar)
    end
    UpdateShownState()
end

function addon.RestoreSwingTimerSystem()
    SwingTimer.applied = false

    eventFrame:UnregisterAllEvents()
    UpdateCallbacks()
    for _, bar in ipairs(bars) do
        bar.previewing = false
        Clear(bar)
        addon.SetShownFaded(bar.frame, false, false, bar.setFade)
    end
end

function addon.RefreshSwingTimerSystem()
    if addon:IsModuleEnabled(KEY) then
        addon.ApplySwingTimerSystem()
    else
        addon.RestoreSwingTimerSystem()
    end
end

-- Entry point for the editor sliders and toggles.
function addon.RefreshSwingTimer()
    if not SwingTimer.applied then return end

    UpdateCallbacks()
    for _, bar in ipairs(bars) do Layout(bar) end
    UpdateShownState()
end
