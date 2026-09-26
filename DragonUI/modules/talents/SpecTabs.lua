-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
addon.TalentModule = addon.TalentModule or {}
local L = addon.L
local T = addon.TalentModule

local MAX_NAME = 16
local TAB_PREFIX = "DragonUI_TalentFrameTab"
local PET_TAB, GLYPH_TAB = 3, 4
local NUM_TABS = 4

-- ============================================================================
-- Custom spec names (per character)
-- ============================================================================
local function specNames()
    local char = addon.db and addon.db.char
    if not char then return nil end
    char.talentSpecNames = char.talentSpecNames or {}
    return char.talentSpecNames
end

local function customName(group)
    local names = specNames()
    return names and names[group]
end

function T.SpecName(group)
    return customName(group) or ((group == 2) and TALENT_SPEC_SECONDARY or TALENT_SPEC_PRIMARY)
end

-- Pipes would open escape sequences in every label that shows the name; the box already caps length.
local function cleanName(name)
    local clean = (name or ""):gsub("[%c|]", "")
    return clean
end

local function setCustomName(group, name)
    local names = specNames()
    if not names then return end
    name = strtrim(cleanName(name))
    names[group] = (name ~= "") and name or nil
end

StaticPopupDialogs["DUI_TALENT_RENAME_SPEC"] = {
    text = L["Rename this specialization (max %d characters):"],
    button1 = ACCEPT, button2 = CANCEL,
    hasEditBox = 1, maxLetters = MAX_NAME, timeout = 0, whileDead = 1, hideOnEscape = 1, exclusive = 1,
    OnShow = function(self, data)
        self.editBox:SetText((data and customName(data.group)) or "")
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    EditBoxOnTextChanged = function(self)
        local txt = self:GetText()
        local clean = cleanName(txt)
        if clean ~= txt then self:SetText(clean) end
    end,
    OnAccept = function(self, data)
        if not data then return end
        setCustomName(data.group, self.editBox:GetText())
        T.RefreshSpecTabs()
    end,
    EditBoxOnEnterPressed = function(self) StaticPopup_OnClick(self:GetParent(), 1) end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

-- ============================================================================
-- Tabs: 1-2 = specs, 3 = pet, 4 = glyphs
-- ============================================================================
local function tab(i) return _G[TAB_PREFIX .. i] end

local function layoutTabs()
    local f, prev = T.frame, nil
    for i = 1, NUM_TABS do
        local t = tab(i)
        if t and t:IsShown() then
            t:ClearAllPoints()
            if prev then
                t:SetPoint("TOPLEFT", prev, "TOPRIGHT", 4, 0)
            else
                t:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 11, 2)
            end
            prev = t
        end
    end
end

-- The editor lives on the talent grid; leaving it first keeps a stray tab click from dropping a build.
local function leaveEditor()
    if T._mode ~= "edit" then return true end
    T.RequestExitEditor()
    return T._mode ~= "edit"
end

local function selectTab(id)
    if not leaveEditor() then return end
    PlaySound("igCharacterInfoTab")
    if id == GLYPH_TAB then
        T.SetPetView(false)
        T.SetGlyphView(true)
    elseif id == PET_TAB then
        T.SetGlyphView(false)
        T.SetPetView(true)
    else
        T.SetGlyphView(false)
        T.SetPetView(false)
        T.SetViewGroup(id)
    end
    T.Refresh()
end

local function specTooltip(self)
    local group = self:GetID()
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(T.SpecName(group), 1, 1, 1)
    local points = {}
    for t = 1, GetNumTalentTabs(false, false) or 0 do
        local _, _, spent = GetTalentTabInfo(t, false, false, group)
        points[#points + 1] = tostring(spent or 0)
    end
    if #points > 0 then GameTooltip:AddLine(table.concat(points, " / "), 1, 0.82, 0) end
    if group == (GetActiveTalentGroup(false, false) or 1) then
        GameTooltip:AddLine(TALENT_ACTIVE_SPEC_STATUS, 0.1, 1, 0.1)
    end
    GameTooltip:Show()
end

T.SpecTooltip = specTooltip

T.OnBuild(function(f)
    for i = 1, NUM_TABS do
        local t = CreateFrame("Button", TAB_PREFIX .. i, f.tabHolder, "CharacterFrameTabButtonTemplate")
        t:SetID(i)
        t:SetScript("OnClick", function(self) selectTab(self:GetID()) end)
        if i <= 2 then
            t:SetScript("OnEnter", specTooltip)
            t:SetScript("OnLeave", function() GameTooltip:Hide() end)
        end
        -- How characterpanel/tabs.lua's PanelTemplates_TabResize hook re-chains this strip.
        t._duiRelayout = layoutTabs
    end
    PanelTemplates_SetNumTabs(f, NUM_TABS)

    local cog = CreateFrame("Button", "DragonUI_TalentSpecCog", f.barFrame)
    cog:SetSize(18, 18)
    cog:SetPoint("TOPRIGHT", f.bg, "TOPRIGHT", -8, -8)
    local gear = cog:CreateTexture(nil, "ARTWORK")
    gear:set_atlas("questlog-icon-setting", true)
    gear:SetPoint("CENTER")
    local glow = cog:CreateTexture(nil, "HIGHLIGHT")
    glow:set_atlas("questlog-icon-setting", true)
    glow:SetPoint("CENTER")
    glow:SetBlendMode("ADD")
    glow:SetAlpha(0.4)
    cog:SetScript("OnClick", function()
        StaticPopup_Show("DUI_TALENT_RENAME_SPEC", MAX_NAME, nil, { group = (T.ViewGroup()) })
    end)
    cog:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Rename specialization"], 1, 1, 1)
        GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
    cog:Hide()
    f.specCog = cog
end)

function T.RefreshSpecTabs()
    local f = T.frame
    if not (f and f:IsShown()) then return end
    local CP = addon.CharacterPanel
    local inspect = T._mode == "inspect"
    local numGroups = GetNumTalentGroups(false, false) or 1
    local glyphs, pet = T.GlyphViewActive(), T.PetViewActive()

    local shown = {
        [1] = not inspect,
        [2] = not inspect and numGroups >= 2,
        [PET_TAB] = not inspect and T.PetHasTalents(),
        [GLYPH_TAB] = not inspect and (UnitLevel("player") or 0) >= SHOW_INSCRIPTION_LEVEL,
    }
    for i = 1, NUM_TABS do
        local t = tab(i)
        if i == 1 then
            t:SetText(numGroups >= 2 and T.SpecName(1) or TALENTS)
        elseif i == 2 then
            t:SetText(T.SpecName(2))
        elseif i == PET_TAB then
            t:SetText(PET)
        else
            t:SetText(GLYPHS)
        end
        t:SetShownReq(shown[i])
        if shown[i] and CP and CP.ReskinTab then CP.ReskinTab(t) end
    end

    local selected
    if glyphs then selected = GLYPH_TAB elseif pet then selected = PET_TAB else selected = (T.ViewGroup()) end
    PanelTemplates_SetTab(f, selected)
    layoutTabs()

    f.specCog:SetShownReq(not inspect and not glyphs and not pet and T._mode ~= "edit" and numGroups >= 2)
end
