local addon = select(2, ...)
local NP = addon.Nameplates

-- Retail (TWW) nameplate atlas: UV rects and a nine-slice builder.

NP.atlas = NP.atlas or {}
local A = NP.atlas

local RETAIL = "Interface\\AddOns\\DragonUI\\Textures\\Nameplates\\Retail\\"

A.SHEET = {
    plate = RETAIL .. "nameplate-atlas",
    bar = RETAIL .. "nameplate-bar",
    cast = RETAIL .. "castbar-atlas",
}

-- StatusBar rewrites its texture's texcoords, so every bar fill ships as its own file.
A.CAST_FILL = {
    standard = RETAIL .. "cast-fill-standard",
    channel = RETAIL .. "cast-fill-channel",
    uninterruptible = RETAIL .. "cast-fill-uninterruptible",
    interrupted = RETAIL .. "cast-fill-interrupted",
}

-- Mask pre-baked into the art: 3.3.5a has no CreateMaskTexture.
A.AGGRO_FLARE = RETAIL .. "aggro-flare"

-- file, left, right, top, bottom, native w, native h, then nine-slice margins l/t/r/b.
A.KEYS = {
    selected = { A.SHEET.plate, 0.001953, 0.423828, 0.796875, 0.937500, 216, 18, 8, 8, 8, 8 },
    deselected = { A.SHEET.plate, 0.431641, 0.841797, 0.632812, 0.726562, 210, 12, 5, 5, 5, 5 },
    -- Starts at the sheet's row 0: cropping one row lower cost the rim a shadow row and
    -- turned retail's documented bgTexture inset of 3 into 2.
    -- mL is 12, not AtlasSlice's 121: retail stretches one middle pixel, 12 is this cap's end.
    barBg = { A.SHEET.bar, 0.347656, 0.863281, 0.000000, 0.148438, 132, 19, 12, 7, 12, 10 },
    -- Retail nine-slices the fill inside the value rect, so its 2px chamfer never scales off the cavity's.
    barFill = { A.SHEET.bar, 0.347656, 0.832031, 0.171875, 0.250000, 124, 10, 4, 5, 4, 4 },
    castBg = { A.SHEET.cast, 0.111328, 0.519531, 0.332031, 0.375000, 209, 11 },
    castFrame = { A.SHEET.cast, 0.001953, 0.419922, 0.121094, 0.183594, 214, 16, 12, 6, 12, 6 },
    castShield = { A.SHEET.cast, 0.001953, 0.107422, 0.332031, 0.582031, 54, 64 },
    castGlow = { A.SHEET.cast, 0.423828, 0.841797, 0.191406, 0.253906, 214, 16 },
    castGlowChannel = { A.SHEET.cast, 0.001953, 0.419922, 0.191406, 0.253906, 214, 16 },
}

-- Whole region onto one texture.
function A.Apply(tex, key, sizeToNative)
    local k = A.KEYS[key]
    if not tex or not k then
        return false
    end
    tex:SetTexture(k[1])
    tex:SetTexCoord(k[2], k[3], k[4], k[5])
    if sizeToNative then
        tex:SetSize(k[6], k[7])
    end
    return true
end

-- Nine pieces: 1..3 top row, 4..6 middle, 7..9 bottom, left to right.
function A.CreateSlice(parent, layer)
    local slice = { parent = parent, layer = layer or "OVERLAY", shown = false }
    for i = 1, 9 do
        slice[i] = parent:CreateTexture(nil, slice.layer)
        slice[i]:Hide()
    end
    return slice
end

function A.SetSliceVertexColor(slice, r, g, b, a)
    if not slice then
        return
    end
    for i = 1, 9 do
        slice[i]:SetVertexColor(r, g, b, a or 1)
    end
end

function A.ShowSlice(slice)
    if not slice or slice.shown then
        return
    end
    slice.shown = true
    for i = 1, 9 do
        if not slice.collapsed or not slice.collapsed[i] then
            slice[i]:Show()
        end
    end
end

function A.HideSlice(slice)
    if not slice or slice.shown == false then
        return
    end
    slice.shown = false
    for i = 1, 9 do
        slice[i]:Hide()
    end
end

-- Reused every call: the fill is relaid on each health tick, so no per-call tables.
local colX, colW, colL, colR = {}, {}, {}, {}
local rowY, rowH, rowT, rowB = {}, {}, {}, {}

-- Lays nine pieces over anchor's rect grown by the four pads. Margins scale with the
-- art's render ratio, so the rails keep their proportion at any bar height.
function A.LayoutSlice(slice, key, anchor, w, h, padL, padT, padR, padB)
    local k = A.KEYS[key]
    if not slice or not k or not anchor then
        return false
    end
    local nativeW, nativeH = k[6], k[7]
    local mL, mT, mR, mB = k[8] or 0, k[9] or 0, k[10] or 0, k[11] or 0
    padL, padT, padR, padB = padL or 0, padT or 0, padR or 0, padB or 0

    local rectW = w + padL + padR
    local rectH = h + padT + padB
    if rectW <= 0 or rectH <= 0 then
        A.HideSlice(slice)
        return false
    end

    -- Margins are fixed regions (rim, drop shadow): the engine stretches only the middle.
    -- Scaling them up would drag the art's bottom rim past the fill it is meant to frame.
    local scale = rectH / nativeH
    if scale > 1 then
        scale = 1
    end
    local capL, capT, capR, capB = mL * scale, mT * scale, mR * scale, mB * scale
    if capL + capR > rectW then
        local f = rectW / (capL + capR)
        capL, capR = capL * f, capR * f
    end
    if capT + capB > rectH then
        local f = rectH / (capT + capB)
        capT, capB = capT * f, capB * f
    end

    local l, r, t, b = k[2], k[3], k[4], k[5]
    local uL = (r - l) * (mL / nativeW)
    local uR = (r - l) * (mR / nativeW)
    local uT = (b - t) * (mT / nativeH)
    local uB = (b - t) * (mB / nativeH)

    local midW = rectW - capL - capR
    local midH = rectH - capT - capB
    slice.collapsed = slice.collapsed or {}
    local col = slice.collapsed
    slice.keyed = slice.keyed or {}
    local keyed = slice.keyed
    local geo = slice.geo
    if not geo then
        geo = { x = {}, y = {}, w = {}, h = {}, anchor = {} }
        slice.geo = geo
    end

    -- Every piece anchors to the reference rect, never to a sibling: a collapsed
    -- piece keeps stale geometry and would drag its neighbours off.
    colX[1], colW[1], colL[1], colR[1] = -padL, capL, l, l + uL
    colX[2], colW[2], colL[2], colR[2] = -padL + capL, midW, l + uL, r - uR
    colX[3], colW[3], colL[3], colR[3] = -padL + capL + midW, capR, r - uR, r
    rowY[1], rowH[1], rowT[1], rowB[1] = padT, capT, t, t + uT
    rowY[2], rowH[2], rowT[2], rowB[2] = padT - capT, midH, t + uT, b - uB
    rowY[3], rowH[3], rowT[3], rowB[3] = padT - capT - midH, capB, b - uB, b

    for row = 1, 3 do
        for colIdx = 1, 3 do
            local i = (row - 1) * 3 + colIdx
            local tex = slice[i]
            local cw, ch = colW[colIdx], rowH[row]
            if cw <= 0 or ch <= 0 then
                if not col[i] then
                    col[i] = true
                    tex:Hide()
                end
            else
                local wasCollapsed = col[i]
                col[i] = nil
                -- Sheet and UVs only move when the key does.
                if keyed[i] ~= key then
                    keyed[i] = key
                    tex:SetTexture(k[1])
                    tex:SetTexCoord(colL[colIdx], colR[colIdx], rowT[row], rowB[row])
                    tex:ClearAllPoints()
                    geo.anchor[i] = nil
                end
                -- A fill tick only moves the middle and right columns; skip the pieces that held still.
                if geo.w[i] ~= cw or geo.h[i] ~= ch then
                    geo.w[i], geo.h[i] = cw, ch
                    tex:SetSize(cw, ch)
                end
                local x, y = colX[colIdx], rowY[row]
                if geo.anchor[i] ~= anchor or geo.x[i] ~= x or geo.y[i] ~= y then
                    geo.anchor[i], geo.x[i], geo.y[i] = anchor, x, y
                    tex:SetPoint("TOPLEFT", anchor, "TOPLEFT", x, y)
                end
                -- Show/HideSlice keep every non-collapsed piece in step with slice.shown.
                if wasCollapsed and slice.shown then
                    tex:Show()
                end
            end
        end
    end

    return true
end
