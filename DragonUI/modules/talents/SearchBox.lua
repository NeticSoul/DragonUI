-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local L = addon.L
local T = addon.TalentModule

local SEARCH_H = 22
local SEARCH_IC = addon._dir .. "Collections\\UI-Searchbox-Icon"

local searchEdit = nil
local searchGlass = nil
local searchHint = nil

function T.SearchUpdate(query)
    if not T.frame then return end
    local q = (query or ""):lower()
    local hasQuery = q ~= ""
    for i = 1, 3 do
        local tf = T.frame.trees[i]
        if tf then
            for idx, node in pairs(tf.nodePool or {}) do
                if node and node:IsShown() then
                    if not hasQuery then
                        node:SetAlpha(1)
                        if node.icon and node.icon.SetDesaturated then node.icon:SetDesaturated(false) end
                        if node.ring and node.ring.SetDesaturated then node.ring:SetDesaturated(false) end
                        if node._duiSearchIcon then node._duiSearchIcon:Hide() end
                    else
                        local tipName = (node._tipName or ""):lower()
                        local desc    = (node._tipDesc or ""):lower()
                        local match = tipName:find(q, 1, true) ~= nil or desc:find(q, 1, true) ~= nil
                        if match then
                            node:SetAlpha(1)
                            if node.icon and node.icon.SetDesaturated then node.icon:SetDesaturated(false) end
                            if node.ring and node.ring.SetDesaturated then node.ring:SetDesaturated(false) end
                            if not node._duiSearchIcon then
                                local ic = node:CreateTexture(nil, "OVERLAY", nil, 5)
                                ic:SetTexture(SEARCH_IC)
                                ic:SetSize(14, 14)
                                ic:SetPoint("TOPRIGHT", node, "TOPRIGHT", 2, 2)
                                node._duiSearchIcon = ic
                            end
                            node._duiSearchIcon:Show()
                        else
                            node:SetAlpha(0.18)
                            if node.icon and node.icon.SetDesaturated then node.icon:SetDesaturated(true) end
                            if node.ring and node.ring.SetDesaturated then node.ring:SetDesaturated(true) end
                            if node._duiSearchIcon then node._duiSearchIcon:Hide() end
                        end
                    end
                end
            end
        end
    end
end

local function buildSearchBox()
    if searchEdit then return end
    local f = T.frame
    if not f then return end

    searchEdit = CreateFrame("EditBox", "DragonUI_TalentSearchEdit", f, "InputBoxTemplate")
    searchEdit:SetSize(180, SEARCH_H)
    if f.pointsText then
        local _dd = _G["DragonUI_TalentLoadoutsFilter"]
        if _dd then
            searchEdit:SetPoint("BOTTOMLEFT", _dd, "BOTTOMRIGHT", 15, 0)
        else
            searchEdit:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 240, (T.FRAME.CHROME_B or 0) + 8)
        end
    else
        searchEdit:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 220, (T.FRAME and T.FRAME.CHROME_B) or 0 + 8)
    end
    searchEdit:SetAutoFocus(false)
    searchEdit:SetTextInsets(18, 6, 0, 0)
    searchEdit:SetFont("Fonts\\FRIZQT__.TTF", 10)
    searchEdit:SetText("")

    searchGlass = searchEdit:CreateTexture(nil, "OVERLAY")
    searchGlass:SetSize(14, 14)
    searchGlass:SetPoint("LEFT", searchEdit, "LEFT", 2, -1.5)
    searchGlass:SetTexture(SEARCH_IC)

    searchHint = searchEdit:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    searchHint:SetPoint("LEFT", searchEdit, "LEFT", 20, 0)
    searchHint:SetText(L["Search talents"] or "Search talents")

    searchEdit:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then searchHint:Show() else searchHint:Hide() end
        T.SearchUpdate(text)
    end)
    searchEdit:SetScript("OnEditFocusGained", function() searchHint:Hide() end)
    searchEdit:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then searchHint:Show() end
    end)
    searchEdit:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus(); T.SearchUpdate("") end)
    searchEdit:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
end

function T.BuildSearchBox()
    if T._glyphActive then return end
    buildSearchBox()
end
