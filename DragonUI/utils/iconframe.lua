-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
-- DragonUI - Icon Frame Utility
-- Shared action-bar icon chrome (buttons.lua) for icons that are plain Textures
-- rather than Buttons: castbars, nameplate castbars, guild perk rows. Also the
-- Collections journal's ornate gold frame, for a single feature icon.
-- ============================================================================

local addon = select(2, ...)

local FRAME_TEXTURE = addon._dir .. "ActionBars\\uiactionbariconframe.tga"
-- Same frame in white: the gold one muddies any SetVertexColor tint.
local FRAME_TEXTURE_WHITE = addon._dir .. "ActionBars\\uiactionbariconframe_white.tga"

local BAR_REF = 37 -- buttons.lua styles 37px buttons; its 2.2px overhang is tuned for that
local OVERHANG = 2.2
local MIN_SCALE = 0.45 -- below this the frame art reads as a thick blob on tiny icons

-- Keeps the same frame/icon ratio as a 37px action button.
local function GetOverhang(size)
    local scale = (size or BAR_REF) / BAR_REF
    if scale < MIN_SCALE then scale = MIN_SCALE end
    return OVERHANG * scale
end

-- Extra pixels a row of framed icons needs so neighbouring frames stop overlapping.
function addon.GetIconFrameGap(size, baseGap)
    local deficit = (2 * GetOverhang(size)) - (baseGap or 0)
    if deficit <= 0 then return 0 end
    return math.ceil(deficit)
end

function addon.CreateIconFrameTexture(host, layer, sublayer)
    if not host or not host.CreateTexture then return nil end
    local tex = host:CreateTexture(nil, layer or "OVERLAY", nil, sublayer)
    tex:SetTexture(FRAME_TEXTURE)
    tex:Hide()
    return tex
end

function addon.SetIconFrameTextureTinted(tex, tinted)
    if not tex or tex._duiTinted == tinted then return end
    tex._duiTinted = tinted
    tex:SetTexture(tinted and FRAME_TEXTURE_WHITE or FRAME_TEXTURE)
end

-- The ornate gold frame's opening is measured where the ring turns solid: its fully transparent
-- core is far smaller than the gold bars actually enclose, and its centre sits high and left of the
-- art. Flourishes run past the bars on the left and below, so the frame is about twice the icon.
addon.GOLD_ICON_FRAME = {
    texture = addon._dir .. "Collections\\IconFrameGold",
    open = 0.4922, cx = 0.4727, cy = 0.4336,
}

-- Sizes the ornate frame so its opening fits a size-px icon and centres that opening on it.
function addon.LayoutGoldIconFrame(tex, icon, size)
    if not tex or not icon then return end
    local g = addon.GOLD_ICON_FRAME
    local frameSize = size / g.open
    tex:SetTexture(g.texture)
    tex:SetSize(frameSize, frameSize)
    tex:ClearAllPoints()
    tex:SetPoint("CENTER", icon, "CENTER", (0.5 - g.cx) * frameSize, (g.cy - 0.5) * frameSize)
end

function addon.LayoutIconFrameTexture(tex, icon, size)
    if not tex or not icon then return end
    local o = GetOverhang(size or icon:GetWidth())
    tex:ClearAllPoints()
    tex:SetPoint("TOPRIGHT", icon, "TOPRIGHT", o, o)
    tex:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -o, -o)
end
