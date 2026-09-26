-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local L = addon.L
local T = addon.TalentModule

local SEARCH_W, SEARCH_H = 184, 22
local SEARCH_DIM = 0.25

-- Name match only, the way New Era does it: the description is not readable without a tooltip scan.
function T.ApplySearch()
    local f = T.frame
    if not (f and f.trees) then return end
    local q = T._search
    local active = q and q ~= ""
    for _, tf in ipairs(f.trees) do
        for _, n in pairs(tf.nodePool) do
            if n:IsShown() then
                if not active then
                    n:SetAlpha(1)
                else
                    local name = n._talentName and string.lower(n._talentName)
                    n:SetAlpha((name and name:find(q, 1, true)) and 1 or SEARCH_DIM)
                end
            end
        end
    end
end

T.OnBuild(function(f)
    -- Named because InputBoxTemplate builds its border out of $parent-prefixed regions.
    local sb = CreateFrame("EditBox", "DragonUI_TalentSearchBox", f.barFrame, "InputBoxTemplate")
    sb:SetSize(SEARCH_W, SEARCH_H)
    sb:SetPoint("LEFT", f.loadout, "RIGHT", 20, 0)
    sb:SetAutoFocus(false)
    sb:SetTextInsets(18, 6, 0, 0)

    local glass = sb:CreateTexture(nil, "OVERLAY")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", sb, "LEFT", 2, -1.5)
    glass:SetTexture(addon._dir .. "Collections\\UI-Searchbox-Icon")

    local hint = sb:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", sb, "LEFT", 20, 0)
    hint:SetText(L["Search talents"])

    sb:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then hint:Show() else hint:Hide() end
        local q = string.lower(text)
        if q ~= T._search then
            T._search = q
            T.ApplySearch()
        end
    end)
    sb:SetScript("OnEditFocusGained", function() hint:Hide() end)
    sb:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then hint:Show() end
    end)
    sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    f.search = sb
    -- The footer runs in a row from here: at 980 wide a centred Apply would sit on this box.
    f.apply:ClearAllPoints()
    f.apply:SetPoint("LEFT", sb, "RIGHT", 24, 0)
end)
