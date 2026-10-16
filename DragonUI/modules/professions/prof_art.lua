-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local Art = {}
P.Art = Art

-- Number12FontOutline, the rank bars' font in Forever: the client's number font at 12 with a thin black outline.
Art.RankFont = CreateFont("DragonUI_ProfessionsRankFont")
do
    local path = NumberFontNormal:GetFont()
    Art.RankFont:SetFont(path, 12, "OUTLINE")
end

-- Number12FontOutline kerns "/" into the digit before it (Forever too); as its own string it keeps its bearings.
local SLASH_GAP = 0

function Art.RankText(parent)
    local rt = {}
    rt.left = parent:CreateFontString(nil, "OVERLAY")
    rt.slash = parent:CreateFontString(nil, "OVERLAY")
    rt.right = parent:CreateFontString(nil, "OVERLAY")
    for _, fs in ipairs({ rt.left, rt.slash, rt.right }) do fs:SetFontObject(Art.RankFont) end
    rt.slash:SetText("/")
    rt.left:SetPoint("RIGHT", rt.slash, "LEFT", -SLASH_GAP, 0)
    rt.right:SetPoint("LEFT", rt.slash, "RIGHT", SLASH_GAP, 0)
    -- The whole "<prefix>/<max>" is centred on this point, as the single string was.
    function rt:SetCenter(relative, relPoint, x, y)
        self.at = { relative, relPoint, x or 0, y or 0 }
    end
    function rt:Set(prefix, max)
        max = tostring(max)
        self.full = prefix .. "/" .. max
        self.left:SetText(prefix)
        self.right:SetText(max)
        local w1, ws, w2 = self.left:GetStringWidth(), self.slash:GetStringWidth(), self.right:GetStringWidth()
        local x = self.at[3] - (w1 + ws + w2 + 2 * SLASH_GAP) / 2 + w1 + SLASH_GAP + ws / 2
        self.slash:ClearAllPoints()
        self.slash:SetPoint("CENTER", self.at[1], self.at[2], math.floor(x + 0.5), self.at[4])
    end
    return rt
end

-- Brightened DXT sheets (SheetShade) are darkened back by the vertex colour; every other sheet resets it to white.
local function paint(texture, file)
    texture:SetTexture(file)
    local shade = P.SheetShade[file] or 1
    texture:SetVertexColor(shade, shade, shade)
end

function Art.Set(texture, name, useSize)
    local info = P.Atlas[name]
    if not info then return nil end
    paint(texture, info[1])
    texture:SetTexCoord(info[4], info[5], info[6], info[7])
    if useSize then texture:SetSize(info[2], info[3]) end
    return info
end

-- An atlas entry with `inset` cut off every side, so it ends that far inside the box it was drawn for.
function Art.SetInset(texture, name, inset)
    local info = Art.Set(texture, name)
    if not info then return nil end
    local dx, dy = inset / info[2] * (info[5] - info[4]), inset / info[3] * (info[7] - info[6])
    texture:SetTexCoord(info[4] + dx, info[5] - dx, info[6] + dy, info[7] - dy)
    texture:SetSize(info[2] - 2 * inset, info[3] - 2 * inset)
    return info
end

-- Only the top-left `width` x `height` of an atlas entry; whatever lies past them is cut.
function Art.SetClipped(texture, name, width, height)
    local info = Art.Set(texture, name)
    if not info then return nil end
    local w, h = math.min(width, info[2]), math.min(height, info[3])
    texture:SetTexCoord(info[4], info[4] + (info[5] - info[4]) * w / info[2],
                        info[6], info[6] + (info[7] - info[6]) * h / info[3])
    texture:SetSize(w, h)
    return info
end

-- The part of an atlas entry from `from` to `to` (its own units, left to right) at its natural height.
function Art.SetSpan(texture, name, from, to)
    local info = P.Atlas[name]
    local w, span = info[2], info[5] - info[4]
    paint(texture, info[1])
    texture:SetTexCoord(info[4] + span * from / w, info[4] + span * to / w, info[6], info[7])
    texture:SetSize(to - from, info[3])
end

-- Left cap, stretched middle, right cap of one atlas entry; returns the three textures.
function Art.ThreeSlice(parent, layer, name, cap)
    local info = P.Atlas[name]
    local capTex = cap / info[2] * (info[5] - info[4])
    local left = parent:CreateTexture(nil, layer)
    local middle = parent:CreateTexture(nil, layer)
    local right = parent:CreateTexture(nil, layer)
    for _, t in ipairs({ left, middle, right }) do paint(t, info[1]) end
    left:SetTexCoord(info[4], info[4] + capTex, info[6], info[7])
    middle:SetTexCoord(info[4] + capTex, info[5] - capTex, info[6], info[7])
    right:SetTexCoord(info[5] - capTex, info[5], info[6], info[7])
    left:SetWidth(cap)
    right:SetWidth(cap)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    return left, middle, right
end

-- Nine pieces cut from one atlas entry with equal margins; the centre is left out when it is transparent.
function Art.NineSlice(parent, layer, name, margin, withCentre)
    local info = P.Atlas[name]
    local l, r, t, b = info[4], info[5], info[6], info[7]
    local mx, my = margin / info[2] * (r - l), margin / info[3] * (b - t)
    local xs, ys = { l, l + mx, r - mx, r }, { t, t + my, b - my, b }
    local pieces = {}
    for row = 1, 3 do
        for col = 1, 3 do
            if withCentre or row ~= 2 or col ~= 2 then
                local tex = parent:CreateTexture(nil, layer)
                paint(tex, info[1])
                tex:SetTexCoord(xs[col], xs[col + 1], ys[row], ys[row + 1])
                pieces[row * 3 + col - 3] = tex
            end
        end
    end
    return pieces
end

-- Lays out Art.NineSlice pieces over `region`: corners at the margin size, edges stretched between them.
function Art.PlaceNineSlice(p, region, margin)
    for i, point in pairs({ [1] = "TOPLEFT", [3] = "TOPRIGHT", [7] = "BOTTOMLEFT", [9] = "BOTTOMRIGHT" }) do
        p[i]:ClearAllPoints()
        p[i]:SetSize(margin, margin)
        p[i]:SetPoint(point, region, point, 0, 0)
    end
    local function span(i, from, fromPoint, to, toPoint)
        if not p[i] then return end
        p[i]:ClearAllPoints()
        p[i]:SetPoint("TOPLEFT", p[from], fromPoint, 0, 0)
        p[i]:SetPoint("BOTTOMRIGHT", p[to], toPoint, 0, 0)
    end
    span(2, 1, "TOPRIGHT", 3, "BOTTOMLEFT")
    span(8, 7, "TOPRIGHT", 9, "BOTTOMLEFT")
    span(4, 1, "BOTTOMLEFT", 7, "TOPRIGHT")
    span(6, 3, "BOTTOMLEFT", 9, "TOPRIGHT")
    span(5, 1, "BOTTOMRIGHT", 9, "TOPLEFT")
end

-- The cards share one parchment (card-base); a profession only adds the box its drawing lives in.
function Art.CardDrawing(key)
    local name = key and ("carddraw-" .. key)
    return name and P.Atlas[name] and name or nil
end

function Art.CardNeedsIcon(key)
    return Art.CardDrawing(key) == nil
end

-- Primary banners: the plain banner in two halves plus the profession's drawing box.
function Art.BannerDrawing(key)
    local name = key and ("bannerdraw-" .. key)
    return name and P.Atlas[name] and name or nil
end

-- Skillbar_Fill_Flipbook_<Profession>, with Forever's DefaultBlue when a profession has none.
function Art.Fill(key)
    local name = key and ("rankbar-fill-" .. key)
    return name and P.Atlas[name] and name or "rankbar-fill"
end

function Art.Small(key)
    return "small-" .. key
end
