-- ============================================================================
-- DragonUI - Icon Frame Utility
-- Shared action-bar icon chrome (buttons.lua) for icons that are plain Textures
-- rather than Buttons: castbars, nameplate castbars.
--
-- Copyright (c) 2026 NeticSoul. Released under the MIT License.
-- ============================================================================

local addon = select(2, ...)

local FRAME_TEXTURE = addon._dir .. "ActionBars\\uiactionbariconframe.tga"

local BAR_REF = 37 -- buttons.lua styles 37px buttons; its 2.2px overhang is tuned for that
local OVERHANG = 2.2
local MIN_SCALE = 0.45 -- below this the frame art reads as a thick blob on tiny icons

-- Keeps the same frame/icon ratio as a 37px action button.
local function GetOverhang(size)
    local scale = (size or BAR_REF) / BAR_REF
    if scale < MIN_SCALE then scale = MIN_SCALE end
    return OVERHANG * scale
end

function addon.CreateIconFrameTexture(host, layer, sublayer)
    if not host or not host.CreateTexture then return nil end
    local tex = host:CreateTexture(nil, layer or "OVERLAY", nil, sublayer)
    tex:SetTexture(FRAME_TEXTURE)
    tex:Hide()
    return tex
end

function addon.LayoutIconFrameTexture(tex, icon, size)
    if not tex or not icon then return end
    local o = GetOverhang(size or icon:GetWidth())
    tex:ClearAllPoints()
    tex:SetPoint("TOPRIGHT", icon, "TOPRIGHT", o, o)
    tex:SetPoint("BOTTOMLEFT", icon, "BOTTOMLEFT", -o, -o)
end
