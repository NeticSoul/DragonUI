-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local TAB_PREFIX = "DragonUI_TalentFrameTab"
local NAME_LETTERS = 16

local function characterPanel()
    return addon.CharacterPanel
end

-- Spec names --------------------------------------------------------------------------------------

local function customNames(create)
    local char = addon.db and addon.db.char
    if not char then return nil end
    if create and not char.talentSpecNames then char.talentSpecNames = {} end
    return char.talentSpecNames
end

function ns.SpecName(group)
    local names = customNames(false)
    local custom = names and names[group]
    if type(custom) == "string" and custom ~= "" then return custom end
    return group == 2 and TALENT_SPEC_SECONDARY or TALENT_SPEC_PRIMARY
end

function ns.SpecTooltip(owner, group)
    local spent = {}
    for tab = 1, GetNumTalentTabs(false, false) or 0 do
        local _, _, points = GetTalentTabInfo(tab, false, false, group)
        spent[#spent + 1] = points or 0
    end
    local status = group == ns.ActiveGroup() and { TALENT_ACTIVE_SPEC_STATUS, 0.1, 1, 0.1 } or nil
    ns.Tip(owner, nil, { ns.SpecName(group), 1, 1, 1 }, { table.concat(spent, " / "), 1, 0.82, 0 }, status)
end

-- Tabs --------------------------------------------------------------------------------------------

local function tab(index)
    return _G[TAB_PREFIX .. index]
end

local function chainTabs()
    local previous
    for index = 1, 4 do
        local button = tab(index)
        if button and button:IsShown() then
            button:ClearAllPoints()
            if previous then
                button:SetPoint("TOPLEFT", previous, "TOPRIGHT", 4, 0)
            else
                button:SetPoint("TOPLEFT", ns.win, "BOTTOMLEFT", 11, 2)
            end
            previous = button
        end
    end
end

local function tabClicked(button)
    if ns.edit then
        ns.Call("RequestExitEditor")
        if ns.edit then return end
    end
    PlaySound("igCharacterInfoTab")
    local id = button:GetID()
    if id == 4 then
        ns.wantPet = false
        ns.SetGlyphPage(true)
    elseif id == 3 then
        ns.SetGlyphPage(false)
        ns.wantPet = true
    else
        ns.SetGlyphPage(false)
        ns.wantPet = false
        ns.viewGroup = id
    end
    ns.Refresh()
end

local function tabEnter(button)
    local id = button:GetID()
    if id <= 2 then ns.SpecTooltip(button, id) end
end

function ns.BuildTabs(holder)
    for index = 1, 4 do
        local button = CreateFrame("Button", TAB_PREFIX .. index, holder, "CharacterFrameTabButtonTemplate")
        button:SetID(index)
        button:SetScript("OnClick", tabClicked)
        button:SetScript("OnEnter", tabEnter)
        button:SetScript("OnLeave", GameTooltip_Hide)
        -- characterpanel/tabs.lua calls this instead of re-chaining the character panel's own tabs.
        button._duiRelayout = chainTabs
    end
    PanelTemplates_SetNumTabs(ns.win, 4)
end

function ns.RefreshTabs()
    if not tab(1) then return end
    local outside = ns.inspectUnit == nil
    local dual = ns.PlayerGroups() >= 2
    local wanted = {
        outside,
        outside and dual,
        outside and ns.PetHasTalents(),
        outside and UnitLevel("player") >= (SHOW_INSCRIPTION_LEVEL or 15),
    }
    local labels = {
        dual and ns.SpecName(1) or TALENTS,
        ns.SpecName(2),
        PET,
        GLYPHS,
    }
    local CP = characterPanel()
    for index = 1, 4 do
        local button = tab(index)
        button:SetText(labels[index])
        button:SetShownReq(wanted[index])
        if wanted[index] then
            if CP and CP.ReskinTab then
                CP.ReskinTab(button)
            else
                PanelTemplates_TabResize(button, 0)
            end
        end
    end
    local selected = ns.viewGroup
    if ns.GlyphView() then
        selected = 4
    elseif ns.PetView() then
        selected = 3
    end
    PanelTemplates_SetTab(ns.win, selected)
    chainTabs()
end

-- Spec rename cog ---------------------------------------------------------------------------------

local renameGear

function ns.BuildSpecCog(footer)
    renameGear = ns.MakeCog(footer, "DragonUI_TalentSpecCog")
    renameGear:SetPoint("TOPRIGHT", ns.win, "TOPRIGHT", -8, -(ns.ART_TOP + 8))
    renameGear:SetScript("OnEnter", function(self) ns.TitledTip(self, L["Rename specialization"]) end)
    renameGear:SetScript("OnClick", function()
        StaticPopup_Show("DUI_TALENT_RENAME_SPEC", NAME_LETTERS, nil, ns.viewGroup)
    end)
    renameGear:SetShownReq(false)
end

function ns.UpdateSpecCog()
    if not renameGear then return end
    renameGear:SetShownReq(ns.inspectUnit == nil and not ns.GlyphView() and not ns.PetView()
        and not ns.edit and ns.PlayerGroups() >= 2)
end

local function cleanTyping(editBox)
    local text = editBox:GetText()
    local clean = ns.Scrub(text)
    if clean ~= text then editBox:SetText(clean) end
end

ns.DefinePopup("DUI_TALENT_RENAME_SPEC", L["Rename this specialization (max %d characters):"], ACCEPT, CANCEL, {
    hasEditBox = 1,
    maxLetters = NAME_LETTERS,
    OnShow = function(dialog, group)
        local names = customNames(false)
        local edit = ns.PopupEdit(dialog)
        edit:SetText(names and names[group] or "")
        edit:HighlightText()
        edit:SetFocus()
    end,
    OnAccept = function(self, group)
        local name = ns.Trim(ns.Scrub(ns.PopupEdit(self):GetText() or ""))
        local names = customNames(true)
        if names then names[group] = name ~= "" and name or nil end
        ns.RefreshTabs()
    end,
    EditBoxOnTextChanged = cleanTyping,
    EditBoxOnEnterPressed = ns.EnterAccepts,
    EditBoxOnEscapePressed = ns.EscapeCloses,
}, "dead solo")
