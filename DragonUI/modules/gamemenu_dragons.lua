-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Dragon heads flanking the game-menu button: baked jaw flipbook plus additive fire sprites, on hover.

local SHEET = addon._dir .. "Micromenu\\dragonbreath.tga"
local SHEET_W, SHEET_H = 512, 256
local CELL_W, CELL_H, COLUMNS, FRAMES = 96, 72, 4, 6
local SCALE = 0.35
-- Where the 88x55 head sits inside its cell, and how far its neck tucks under the button.
local CROP_X, CROP_W, CROP_H, TUCK = 4, 88, 55, 15
-- Fire leaves the mouth at this cell point; the opening drops by MOUTH_DROP as the jaw swings.
local MOUTH_X, MOUTH_Y, MOUTH_DROP = 9, 38, 8

local BLOB = { 0, 64 / SHEET_W, 144 / SHEET_H, 208 / SHEET_H }
local LICK = { 64 / SHEET_W, 128 / SHEET_W, 144 / SHEET_H, 208 / SHEET_H }

local OPEN_RATE, CLOSE_RATE, BREATH_AT = 7, 5, 0.5
local EMIT_RATE, POOL = 55, 40
local FLAME_LIFE, FLAME_LIFE_VARY = 0.42, 0.28
local FLAME_SPEED, FLAME_SPEED_VARY = 36, 20

local function cellCoords(index, mirror)
    local column, row = index % COLUMNS, math.floor(index / COLUMNS)
    local left, right = column * CELL_W / SHEET_W, (column + 1) * CELL_W / SHEET_W
    local top, bottom = row * CELL_H / SHEET_H, (row + 1) * CELL_H / SHEET_H
    if mirror then
        left, right = right, left
    end
    return left, right, top, bottom
end

local function spriteCoords(sprite, mirror)
    if mirror then
        return sprite[2], sprite[1], sprite[3], sprite[4]
    end
    return unpack(sprite)
end

-- White-yellow at birth, orange through the middle, dark red as it dies.
local function fireColor(t)
    local green = 0.95 * (1 - t) ^ 1.1 + 0.05
    local blue = math.max(0, 0.5 * (1 - t * 2.2))
    return 1 - 0.25 * t * t, green, blue
end

local function newSprite(holder, mirror, sprite)
    local tex = holder:CreateTexture(nil, "OVERLAY")
    tex:SetTexture(SHEET)
    tex:SetTexCoord(spriteCoords(sprite, mirror))
    tex:SetBlendMode("ADD")
    tex:Hide()
    return tex
end

local function newHead(holder, button, mirror)
    local head = { mirror = mirror, anchor = mirror and "TOPRIGHT" or "TOPLEFT", sign = mirror and -1 or 1, parts = {} }
    local tex = holder:CreateTexture(nil, "BACKGROUND")
    tex:SetTexture(SHEET)
    tex:SetTexCoord(cellCoords(0, mirror))
    tex:SetSize(CELL_W * SCALE, CELL_H * SCALE)
    local x = TUCK + (CELL_W - CROP_X - CROP_W) * SCALE
    local y = CROP_H * SCALE / 2 + 0.5
    if mirror then
        tex:SetPoint("TOPLEFT", button, "RIGHT", -x, y)
    else
        tex:SetPoint("TOPRIGHT", button, "LEFT", x, y)
    end
    head.tex = tex
    head.frame = 1
    head.core = newSprite(holder, mirror, BLOB)
    head.core:SetVertexColor(1, 0.62, 0.2, 0)

    for i = 1, POOL do
        head.parts[i] = { tex = newSprite(holder, mirror, i % 2 == 0 and BLOB or LICK), blob = i % 2 == 0, age = 0, life = 0 }
    end
    return head
end

local function spawn(head)
    for _, part in ipairs(head.parts) do
        if part.life == 0 then
            local speed = FLAME_SPEED + math.random() * FLAME_SPEED_VARY
            local angle = (math.random() - 0.5) * 0.36
            part.age = 0
            part.life = FLAME_LIFE + math.random() * FLAME_LIFE_VARY
            part.vx = -head.sign * speed * math.cos(angle)
            part.vy = speed * math.sin(angle)
            part.rise = 12 + math.random() * 10
            part.phase = math.random() * 6.28
            part.x0, part.y0 = (math.random() - 0.5) * 2, (math.random() - 0.5) * 2
            if part.blob then
                part.w0, part.h0, part.w1, part.h1 = 6, 6, 16, 16
            else
                part.w0, part.h0, part.w1, part.h1 = 18, 8, 30, 14
            end
            return
        end
    end
end

local function stepParts(head, dt)
    local live = 0
    for _, part in ipairs(head.parts) do
        if part.life > 0 then
            part.age = part.age + dt
            if part.age >= part.life then
                part.life = 0
                part.tex:Hide()
            else
                live = live + 1
                local t = part.age / part.life
                local grow = t ^ 0.8
                local red, green, blue = fireColor(t)
                local fade = (t < 0.12 and t / 0.12 or 1) * (1 - t) ^ 1.3 * 0.95
                local x = part.x0 + part.vx * part.age
                local y = part.y0 + part.vy * part.age + 0.5 * part.rise * part.age * part.age
                    + math.sin(part.age * 18 + part.phase) * 1.2
                part.tex:SetVertexColor(red, green, blue, fade)
                part.tex:SetSize(part.w0 + (part.w1 - part.w0) * grow, part.h0 + (part.h1 - part.h0) * grow)
                part.tex:SetPoint("CENTER", head.tex, head.anchor, head.ex + x, head.ey + y)
                part.tex:Show()
            end
        end
    end
    return live
end

local function stepCore(head, open, breathing)
    local core = head.core
    if not breathing then
        core:Hide()
        return
    end
    local size = 8 + 8 * open + math.random() * 2
    core:SetSize(size, size)
    core:SetVertexColor(1, 0.62, 0.2, 0.55 + math.random() * 0.25)
    core:SetPoint("CENTER", head.tex, head.anchor, head.ex, head.ey)
    core:Show()
end

local function tick(driver, elapsed)
    local fx = driver.fx
    local dt = math.min(elapsed, 0.05)
    local target = fx.hover and 1 or 0
    if fx.open < target then
        fx.open = math.min(target, fx.open + dt * OPEN_RATE)
    elseif fx.open > target then
        fx.open = math.max(target, fx.open - dt * CLOSE_RATE)
    end

    local frame = 1 + math.floor(fx.open * (FRAMES - 1) + 0.5)
    local breathing = fx.hover and fx.open >= BREATH_AT
    local births = 0
    if breathing then
        fx.emit = fx.emit + dt * EMIT_RATE
        births = math.floor(fx.emit)
        fx.emit = fx.emit - births
    else
        fx.emit = 0
    end

    local live = 0
    for _, head in ipairs(fx.heads) do
        if frame ~= head.frame then
            head.frame = frame
            head.tex:SetTexCoord(cellCoords(frame - 1, head.mirror))
        end
        head.ex = head.sign * MOUTH_X * SCALE
        head.ey = -(MOUTH_Y + MOUTH_DROP * fx.open) * SCALE
        for _ = 1, births do
            spawn(head)
        end
        stepCore(head, fx.open, breathing)
        live = live + stepParts(head, dt)
    end

    if not fx.hover and fx.open == 0 and live == 0 then
        driver:Hide()
    end
end

local function reset(fx)
    fx.hover, fx.open, fx.emit = false, 0, 0
    for _, head in ipairs(fx.heads) do
        head.frame = 1
        head.tex:SetTexCoord(cellCoords(0, head.mirror))
        head.core:Hide()
        for _, part in ipairs(head.parts) do
            part.life = 0
            part.tex:Hide()
        end
    end
    fx.driver:Hide()
end

-- Child frame one level under the button: the button's own art is drawn over the cut necks, never the reverse.
local function attach(button)
    local holder = CreateFrame("Frame", nil, button)
    holder:SetAllPoints(button)
    holder:SetFrameLevel(math.max(0, button:GetFrameLevel() - 1))
    button._dragonHeads = holder

    local driver = CreateFrame("Frame", nil, holder)
    driver:Hide()
    local fx = { hover = false, open = 0, emit = 0, driver = driver }
    fx.heads = { newHead(holder, button, false), newHead(holder, button, true) }
    driver.fx = fx
    driver:SetScript("OnUpdate", tick)

    button:HookScript("OnEnter", function()
        fx.hover = true
        driver:Show()
    end)
    button:HookScript("OnLeave", function()
        fx.hover = false
    end)
    button:HookScript("OnHide", function()
        reset(fx)
    end)
    return holder
end

addon.GameMenuDragons = { Attach = attach }
