-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- Retail's red three-slice button ("128-RedButton"), for panel buttons that would otherwise show
-- 3.3.5a's stone art. Both caps are the LEFT slice mirrored: the sheet's own right rect is 292px.

local SHEET = addon._dir .. "UI\\redbutton3slice"

-- Native art size of one cap; the caps scale with the button's height so the corner radius holds.
local CAP_W, ART_H = 114, 128

local STATES = {
    NORMAL = { cap = { 0.763672, 0.986328, 0.444824, 0.507324 }, mid = { 0, 0.125, 0.000488, 0.062988 } },
    PUSHED = { cap = { 0.763672, 0.986328, 0.571777, 0.634277 }, mid = { 0, 0.125, 0.127441, 0.189941 } },
    DISABLED = { cap = { 0.763672, 0.986328, 0.508301, 0.570801 }, mid = { 0, 0.125, 0.063965, 0.126465 } },
}

-- One strip holding all three pieces, so a cap's share is its width over the assembled 441.
local HL_LEFT, HL_RIGHT, HL_TOP, HL_BOTTOM = 0.001953, 0.863281, 0.190918, 0.253418
local HL_CAP = (HL_RIGHT - HL_LEFT) * (CAP_W / 441)

local function stateOf(btn)
    if btn.IsEnabled and not btn:IsEnabled() then return "DISABLED" end
    if btn.GetButtonState and btn:GetButtonState() == "PUSHED" then return "PUSHED" end
    return "NORMAL"
end

local function resize(btn)
    local skin = btn._duiRedButton
    local height = btn:GetHeight() or 0
    if not skin or height <= 0 then return end

    local cap = CAP_W * (height / ART_H)
    local width = btn:GetWidth() or 0
    -- Never let the two caps swallow the whole button; the middle has to stay visible for the label.
    if width > 0 and cap * 2 > width * 0.8 then cap = width * 0.4 end

    skin.left:SetSize(cap, height)
    skin.right:SetSize(cap, height)
    skin.hlLeft:SetSize(cap, height)
    skin.hlRight:SetSize(cap, height)
end

local function apply(btn, state)
    local skin = btn._duiRedButton
    if not skin then return end
    local rect = STATES[state or stateOf(btn)] or STATES.NORMAL

    skin.left:SetTexCoord(rect.cap[1], rect.cap[2], rect.cap[3], rect.cap[4])
    -- Mirrored: the right cap samples the same slice right-to-left.
    skin.right:SetTexCoord(rect.cap[2], rect.cap[1], rect.cap[3], rect.cap[4])
    skin.middle:SetTexCoord(rect.mid[1], rect.mid[2], rect.mid[3], rect.mid[4])
    resize(btn)
end

local function strip(btn)
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local tex = btn[getter] and btn[getter](btn)
        if tex then tex:SetTexture(nil) end
    end
end

function addon.SkinRedButton(btn)
    if not btn or btn._duiRedButton then return end
    strip(btn)

    local skin = {}
    btn._duiRedButton = skin

    skin.left = btn:CreateTexture(nil, "BACKGROUND")
    skin.left:SetTexture(SHEET)
    skin.left:SetPoint("TOPLEFT", btn, "TOPLEFT", 0, 0)

    skin.right = btn:CreateTexture(nil, "BACKGROUND")
    skin.right:SetTexture(SHEET)
    skin.right:SetPoint("TOPRIGHT", btn, "TOPRIGHT", 0, 0)

    skin.middle = btn:CreateTexture(nil, "BACKGROUND")
    skin.middle:SetTexture(SHEET)
    skin.middle:SetHorizTile(true)
    skin.middle:SetPoint("TOPLEFT", skin.left, "TOPRIGHT", 0, 0)
    skin.middle:SetPoint("BOTTOMRIGHT", skin.right, "BOTTOMLEFT", 0, 0)

    local function highlight(anchor, point, l, r)
        local tex = btn:CreateTexture(nil, "ARTWORK", nil, 2)
        tex:SetTexture(SHEET)
        tex:SetTexCoord(l, r, HL_TOP, HL_BOTTOM)
        tex:SetBlendMode("ADD")
        tex:Hide()
        if point then tex:SetPoint(point, btn, point, 0, 0) else tex:SetAllPoints(anchor) end
        return tex
    end
    skin.hlLeft = highlight(nil, "TOPLEFT", HL_LEFT, HL_LEFT + HL_CAP)
    skin.hlRight = highlight(nil, "TOPRIGHT", HL_LEFT + HL_CAP, HL_LEFT)
    skin.hlMiddle = highlight(skin.middle, nil, HL_LEFT + HL_CAP, HL_RIGHT - HL_CAP)

    btn:HookScript("OnEnter", function()
        skin.hlLeft:Show(); skin.hlRight:Show(); skin.hlMiddle:Show()
    end)
    btn:HookScript("OnLeave", function(self)
        skin.hlLeft:Hide(); skin.hlRight:Hide(); skin.hlMiddle:Hide()
        -- Released off the button: OnMouseUp never arrives, so the pushed art would stick.
        apply(self)
    end)
    btn:HookScript("OnMouseDown", function(self) apply(self, "PUSHED") end)
    -- Next frame: GetButtonState can still read PUSHED inside OnMouseUp, which re-pins the art.
    btn:HookScript("OnMouseUp", function(self) addon:After(0, function() apply(self) end) end)
    btn:HookScript("OnEnable", function(self) apply(self) end)
    btn:HookScript("OnDisable", function(self) apply(self) end)
    btn:HookScript("OnSizeChanged", function(self) resize(self) end)
    btn:HookScript("OnShow", function(self) apply(self) end)

    apply(btn)
end
