-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local Art = P.Art
local Fill = {}
P.Fill = Fill

-- ProfessionsRankBarMixin: a 2 s flipbook on every change, the fill easing to a new value in 0.5 s, the flare fading in 1 s.
local FLIP_TIME, GROW_TIME, FADE_TIME = 2.0, 0.5, 1.0
local FLARE_W, FILL_W = 53, 441

local running = {}
local driver = CreateFrame("Frame")

-- The fill art keeps its 441 width on every bar; the mask, 1 in from its left, uncovers `width` of it.
local function crop(tex, file, l, r, t, b, width)
    local unit = (r - l) / FILL_W
    tex:SetTexture(file)
    tex:SetTexCoord(l + unit, l + unit * (1 + width), t, b)
    tex:SetWidth(width)
end

-- ProfessionsRankBarMixin:GetMaskWidth: bar width x progress + overrideMaskRightOffset, never past the art.
local function maskWidth(fx, ratio)
    return math.min(fx.barWidth * ratio + fx.maskOffset, FILL_W - 1)
end

local function draw(fx, ratio, frame)
    local width = maskWidth(fx, ratio)
    if ratio <= 0 or width <= 0 then
        fx.base:Hide()
        fx.mod:Hide()
        fx.add:Hide()
        fx.flare:Hide()
        return
    end
    local info = P.Atlas[Art.Fill(fx.key)]
    crop(fx.base, info[1], info[4], info[5], info[6], info[7], width)
    fx.base:Show()
    local anim = frame and P.FillAnim[fx.key]
    if anim then
        local add, mod, x0, y0, fw, fh, pitchX, pitchY, _, sw, sh, lowerRow = unpack(anim)
        local column, row = frame % 2, math.floor(frame / 2)
        local left, top, suffix = x0 + column * pitchX, y0 + row * pitchY, ""
        if lowerRow and row >= lowerRow then top, suffix = top - P.FX_CUT, "2" end
        if column == 1 then left, suffix = left - P.FX_CUT, suffix .. "_r" end
        add, mod = add .. suffix, mod .. suffix
        local l, t = left / sw, top / sh
        local r, b = l + fw / sw, t + fh / sh
        crop(fx.mod, mod, l, r, t, b, width)
        crop(fx.add, add, l, r, t, b, width)
        fx.mod:Show()
        fx.add:Show()
    else
        fx.mod:Hide()
        fx.add:Hide()
    end
    if not fx.flareName then
        fx.flare:Hide()
        return
    end
    -- Forever masks the flare with the fill, so a short fill only shows the flare's right end.
    local flare = P.Atlas[fx.flareName]
    local w = math.min(FLARE_W, width)
    fx.flare:SetTexture(flare[1])
    fx.flare:SetTexCoord(flare[4] + (FLARE_W - w) / FLARE_W * (flare[5] - flare[4]), flare[5], flare[6], flare[7])
    fx.flare:SetWidth(w)
    fx.flare:Show()
end

-- Returns true while anything on the bar is still moving.
local function step(fx, now)
    local busy = false
    local ratio = fx.ratio or 0
    if fx.growFrom then
        local t = (now - fx.growStart) / GROW_TIME
        if t >= 1 then
            fx.growFrom = nil
        else
            ratio = fx.growFrom + (fx.ratio - fx.growFrom) * math.sin(t * math.pi / 2)
            busy = true
        end
    end
    local frame
    if fx.flipStart then
        local anim = P.FillAnim[fx.key]
        local frames = anim and anim[9] * 2
        local f = frames and math.floor((now - fx.flipStart) / FLIP_TIME * frames)
        if f and f < frames - 1 then
            frame, busy = f, true
        else
            fx.flipStart = nil
        end
    end
    if fx.fadeStart then
        local t = (now - fx.fadeStart) / FADE_TIME
        if t >= 1 then
            fx.fadeStart, fx.flareAlpha = nil, 0
        else
            fx.flareAlpha, busy = 1 - math.sin(t * math.pi / 2), true
        end
    end
    if frame ~= fx.shownFrame or ratio ~= fx.shownRatio then
        fx.shownFrame, fx.shownRatio = frame, ratio
        draw(fx, ratio, frame)
    end
    fx.flare:SetAlpha(fx.flareAlpha or 1)
    return busy
end

local function onUpdate()
    local now = GetTime()
    for fx in pairs(running) do
        if not step(fx, now) then running[fx] = nil end
    end
    if not next(running) then driver:SetScript("OnUpdate", nil) end
end

-- Sits where the template's Fill does; layers: raw rest frame, MOD, ADD, flare. The border needs a frame above.
function Fill.Create(parent, barWidth, maskOffset, height)
    local fx = CreateFrame("Frame", nil, parent)
    fx:SetSize(FILL_W, height)
    fx.barWidth, fx.maskOffset = barWidth, maskOffset or 0
    fx.base = fx:CreateTexture(nil, "BACKGROUND")
    fx.mod = fx:CreateTexture(nil, "BORDER")
    fx.mod:SetBlendMode("MOD")
    fx.add = fx:CreateTexture(nil, "ARTWORK")
    fx.add:SetBlendMode("ADD")
    for _, tex in ipairs({ fx.base, fx.mod, fx.add }) do
        tex:SetPoint("TOPLEFT", fx, "TOPLEFT", 1, 0)
        tex:SetHeight(height)
        tex:Hide()
    end
    fx.flare = fx:CreateTexture(nil, "OVERLAY")
    fx.flare:SetBlendMode("ADD")
    fx.flare:SetHeight(16)
    fx.flare:SetPoint("RIGHT", fx.base, "RIGHT", 0, 0)
    fx.flare:Hide()
    -- Forever's OnHide forgets the value and the profession, so the bar plays again every time it shows.
    fx:SetScript("OnHide", function(self)
        self.ratio, self.key, self.shownFrame, self.shownRatio = nil, nil, nil, nil
        running[self] = nil
    end)
    return fx
end

function Fill.Update(fx, key, ratio, isFull)
    local now = GetTime()
    local changed = fx.key ~= key
    if changed then
        fx.key = key
        local flareName = key and ("rankbar-flare-" .. key)
        fx.flareName = flareName and P.Atlas[flareName] and flareName or nil
    end
    local same = fx.ratio == ratio
    if (changed or not same) and key and P.FillAnim[key] then fx.flipStart = now end
    if same and not changed then return end
    if isFull and not changed and not same then
        fx.fadeStart = now
    else
        fx.fadeStart, fx.flareAlpha = nil, isFull and 0 or 1
    end
    if changed then
        fx.growFrom = nil
    else
        fx.growFrom, fx.growStart = fx.ratio or 0, now
    end
    fx.ratio = ratio
    fx.shownFrame, fx.shownRatio = false, false
    if step(fx, now) then
        running[fx] = true
        driver:SetScript("OnUpdate", onUpdate)
    end
end
