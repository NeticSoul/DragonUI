-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local L = addon.L
local T = addon.TalentModule

local MAX_NAME = 16

-- ============================================================================
-- Per-character custom names stored in the module config.
-- ============================================================================
local function moduleConfig()
    local cfg = addon:GetModuleConfig("talents")
    if not cfg then
        return nil
    end
    cfg.talentSpecNames = cfg.talentSpecNames or {}
    return cfg
end
local function charKey()
    return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end
local function customName(group)
    local cfg = moduleConfig()
    local c = cfg and cfg.talentSpecNames and cfg.talentSpecNames[charKey()]
    return c and c[group]
end
local function setCustomName(group, name)
    name = (name or ""):gsub("[^%a ]", "")
    name = name:gsub("^%s+", ""):gsub("%s+$", "")
    if #name > MAX_NAME then name = name:sub(1, MAX_NAME) end
    local cfg = moduleConfig()
    if not cfg then return end
    local key = charKey()
    cfg.talentSpecNames[key] = cfg.talentSpecNames[key] or {}
    cfg.talentSpecNames[key][group] = (name ~= "") and name or nil
end
local function defaultName(group)
    if group == 1 then return "Primary"
    elseif group == 2 then return "Secondary"
    elseif group == 3 then return "Tertiary"
    elseif group == 4 then return "Quaternary"
    end
    return "Spec " .. group
end
local function specName(group) return customName(group) or defaultName(group) end

-- ============================================================================
-- Rename dialog
-- ============================================================================
StaticPopupDialogs["DUI_TALENT_RENAME_SPEC"] = {
    text = (L["Rename this specialization (letters only, max %d):"] or "Rename this specialization (letters only, max %d):"):format(MAX_NAME),
    button1 = ACCEPT or "Accept", button2 = CANCEL or "Cancel",
    hasEditBox = 1, maxLetters = MAX_NAME,
    OnShow = function(self)
        local eb = self.editBox or _G[(self:GetName() or "") .. "EditBox"]
        if not eb then return end
        eb:SetText((self.data and self.data.current) or "")
        eb:HighlightText()
        eb:SetScript("OnTextChanged", function(box)
            local txt = box:GetText()
            local clean = txt:gsub("[^%a ]", "")
            if clean ~= txt then box:SetText(clean) end
        end)
    end,
    OnAccept = function(self)
        local eb = self.editBox or _G[(self:GetName() or "") .. "EditBox"]
        if self.data and self.data.group then
            setCustomName(self.data.group, eb and eb:GetText() or "")
            if T.RefreshSpecTabs then T.RefreshSpecTabs() end
        end
    end,
    EditBoxOnEnterPressed = function(editBox)
        local d = editBox:GetParent()
        if d.data and d.data.group then
            setCustomName(d.data.group, editBox:GetText() or "")
            if T.RefreshSpecTabs then T.RefreshSpecTabs() end
        end
        d:Hide()
    end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
    timeout = 0, whileDead = 1, hideOnEscape = 1, exclusive = 1,
}

-- ============================================================================
-- Tab art (selected/deselected)
-- ============================================================================
-- Position the tab label
local function positionTabText(tab, selected)
    local text = _G[tab:GetName() .. "Text"]
    if text then
        text:ClearAllPoints()
        text:SetPoint("CENTER", tab, "CENTER", TEXT_NUDGE_X,
            selected and TEXT_ACTIVE_DROP or 0)
    end
end

local function applyHighlight(tab, selected)
    for _, piece in ipairs(tab._duiHighlight or {}) do
        if piece then
            local ok = pcall(piece.SetAlpha, piece, selected and 0 or HL_ALPHA)
        end
    end
end

local function setTabArt(tab, selected)
    if not tab then return end
    local n = tab:GetName()
    local function set(suffix, show)
        local t = _G[n .. suffix]
        if t then if show then t:Show() else t:Hide() end end
    end

    set("Left",  not selected); set("Middle",  not selected); set("Right",  not selected)
    set("LeftDisabled", selected); set("MiddleDisabled", selected); set("RightDisabled", selected)

    if selected then
        if PanelTemplates_SelectTab then PanelTemplates_SelectTab(tab) end
        tab:SetDisabledFontObject(GameFontHighlightSmall)
    else
        if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(tab) end
        tab:SetDisabledFontObject(GameFontNormalSmall)
    end

    positionTabText(tab, selected)
    applyHighlight(tab, selected)
end

local TAB_NAMES = { "DragonUI_TalentSpecTab1", "DragonUI_TalentSpecTab2", "DragonUI_TalentSpecTab3", "DragonUI_TalentSpecTab4" }
local GLYPH_TAB_NAME = "DragonUI_TalentSpecTabGlyphs"
local PET_TAB_NAME   = "DragonUI_TalentSpecTabPet"

-- ============================================================================
-- TAB RESKIN (uiframetabs metal sheet, same as bagster / character panel)
-- ============================================================================
local TAB_TEX = addon._dir .. "UI\\uiframetabs"
local CAP_OVERHANG = 5
local ACTIVE_OVERHANG_L, ACTIVE_OVERHANG_R = 4, 6
local HL_ALPHA, HL_H = 0.4, 30
local HL_LEFT_TC   = { 0.015625, 0.5625, 0.816406, 0.933594 }
local HL_RIGHT_TC  = { 0.015625, 0.59375, 0.667969, 0.785156 }
local HL_MIDDLE_TC = { 0, 0.015625, 0.175781, 0.292969 }
local TEXT_ACTIVE_DROP, TEXT_NUDGE_X = -7, -2
local TAB_GAP = 1

local function reskinSingleTab(tabName)
    local tab = _G[tabName]
    if not tab or tab._duiTabReskinned then return end

    tab:SetFrameLevel((tab:GetFrameLevel() or 1) + 4)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)

    local left   = _G[tabName .. "Left"]
    local right  = _G[tabName .. "Right"]
    local middle = _G[tabName .. "Middle"]
    local leftD  = _G[tabName .. "LeftDisabled"]
    local rightD = _G[tabName .. "RightDisabled"]
    local midD   = _G[tabName .. "MiddleDisabled"]

    if left then
        left:ClearAllPoints()
        left:SetSize(35, 36)
        left:SetTexture(TAB_TEX)
        left:SetTexCoord(0.015625, 0.5625, 0.816406, 0.957031)
        left:SetPoint("TOPLEFT", tab, "TOPLEFT", -CAP_OVERHANG, 0)
    end
    if right then
        right:ClearAllPoints()
        right:SetSize(37, 36)
        right:SetTexture(TAB_TEX)
        right:SetTexCoord(0.015625, 0.59375, 0.667969, 0.808594)
        right:SetPoint("TOPRIGHT", tab, "TOPRIGHT", CAP_OVERHANG, 0)
    end
    if middle and left and right then
        middle:ClearAllPoints()
        middle:SetSize(1, 36)
        middle:SetTexture(TAB_TEX)
        middle:SetTexCoord(0, 0.015625, 0.175781, 0.316406)
        middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
        middle:SetPoint("TOPRIGHT", right, "TOPLEFT")
    end

    if leftD then
        leftD:ClearAllPoints()
        leftD:SetSize(35, 42)
        leftD:SetTexture(TAB_TEX)
        leftD:SetTexCoord(0.015625, 0.5625, 0.496094, 0.660156)
        leftD:SetPoint("TOPLEFT", tab, "TOPLEFT", -ACTIVE_OVERHANG_L, 0)
    end
    if rightD then
        rightD:ClearAllPoints()
        rightD:SetSize(37, 42)
        rightD:SetTexture(TAB_TEX)
        rightD:SetTexCoord(0.015625, 0.59375, 0.324219, 0.488281)
        rightD:SetPoint("TOPRIGHT", tab, "TOPRIGHT", ACTIVE_OVERHANG_R, 0)
    end
    if midD and leftD and rightD then
        midD:ClearAllPoints()
        midD:SetSize(1, 42)
        midD:SetTexture(TAB_TEX)
        midD:SetTexCoord(0, 0.015625, 0.00390625, 0.167969)
        midD:SetPoint("TOPLEFT", leftD, "TOPRIGHT")
        midD:SetPoint("TOPRIGHT", rightD, "TOPLEFT")
    end

    local stock = tab:GetHighlightTexture()
    if stock then stock:SetTexture(nil) end

    local function glow(tc, w, anchor)
        local t = tab:CreateTexture(nil, "HIGHLIGHT")
        t:SetTexture(TAB_TEX)
        t:SetTexCoord(unpack(tc))
        t:SetSize(w, HL_H)
        t:SetPoint("TOPLEFT", anchor, "TOPLEFT")
        t:SetBlendMode("ADD")
        t:SetAlpha(HL_ALPHA)
        return t
    end

    local hlLeft  = left  and glow(HL_LEFT_TC,   35, left)
    local hlRight = right and glow(HL_RIGHT_TC,  37, right)
    local hlMid
    if middle then
        hlMid = tab:CreateTexture(nil, "HIGHLIGHT")
        hlMid:SetTexture(TAB_TEX)
        hlMid:SetTexCoord(unpack(HL_MIDDLE_TC))
        hlMid:SetHeight(HL_H)
        hlMid:SetPoint("TOPLEFT", hlLeft, "TOPRIGHT")
        hlMid:SetPoint("TOPRIGHT", hlRight, "TOPLEFT")
        hlMid:SetBlendMode("ADD")
        hlMid:SetAlpha(HL_ALPHA)
    end

    tab._duiHighlight = { hlLeft, hlRight, hlMid }

    local w = 72
    tab._duiWidth = w
    tab:SetWidth(w)

    tab._duiTabReskinned = true
    local origSetWidth = tab.SetWidth
    tab.SetWidth = function(self, w)
        if type(w) == "number" and w > 80 then w = 72 end
        return origSetWidth(self, w)
    end
end

local function buildTab(g)
    local f = T.frame
    local name = TAB_NAMES[g]
    local tab = _G[name]
    if tab then return tab end
    local ok, t = pcall(CreateFrame, "Button", name, f, "CharacterFrameTabButtonTemplate")
    if ok and t then tab = t else
        tab = CreateFrame("Button", name, f, "UIPanelButtonTemplate"); tab._duiPlain = true
    end
    tab:SetID(g)
    tab:SetScript("OnClick", function(self)
        if PlaySound then pcall(PlaySound, "igCharacterInfoTab") end
        local id = self:GetID()
        T._viewGroup = id
        T._petView = false
        if T.GlyphsSetActive then T.GlyphsSetActive(false) end
        if T.GlyphsApplyPaneVisibility then T.GlyphsApplyPaneVisibility() end
        local Fb = (T.frame and T.frame.children and T.frame.children["DragonUI_TalentLoadoutsFilter"]) or _G["DragonUI_TalentLoadoutsFilter"]
        if Fb then
            if T.IsInspecting and T.IsInspecting() or T._petView or (T.GlyphsIsActive and T.GlyphsIsActive()) then
                Fb:Hide()
            else
                Fb:Show()
            end
        end

        if T.RefreshSpecTabs then T.RefreshSpecTabs() end
        if T.Refresh then T.Refresh() end
    end)
    reskinSingleTab(name)
    return tab
end

local function buildGlyphTab()
    local f = T.frame
    local name = GLYPH_TAB_NAME
    local tab = _G[name]
    if tab then return tab end
    local ok, t = pcall(CreateFrame, "Button", name, f, "CharacterFrameTabButtonTemplate")
    if ok and t then tab = t else
        tab = CreateFrame("Button", name, f, "UIPanelButtonTemplate"); tab._duiPlain = true
    end
    tab:SetScript("OnClick", function()
        if PlaySound then pcall(PlaySound, "igCharacterInfoTab") end
        T._petView = false
        if T.GlyphsSetActive then T.GlyphsSetActive(true) end
        local Fb = (T.frame and T.frame.children and T.frame.children["DragonUI_TalentLoadoutsFilter"]) or _G["DragonUI_TalentLoadoutsFilter"]
        if Fb then Fb:Hide() end
        if T.GlyphsRefresh then T.GlyphsRefresh() end
        if T.GlyphsApplyPaneVisibility then T.GlyphsApplyPaneVisibility() end
        if T.RefreshSpecTabs then T.RefreshSpecTabs() end
    end)
    reskinSingleTab(name)
    return tab
end

local function buildPetTab()
    local f = T.frame
    local name = PET_TAB_NAME
    local tab = _G[name]
    if tab then return tab end
    local ok, t = pcall(CreateFrame, "Button", name, f, "CharacterFrameTabButtonTemplate")
    if ok and t then tab = t else
        tab = CreateFrame("Button", name, f, "UIPanelButtonTemplate"); tab._duiPlain = true
    end
    tab:SetScript("OnClick", function()
        if PlaySound then pcall(PlaySound, "igCharacterInfoTab") end
        if T.SetPetView then T.SetPetView(true) else T._petView = true end
        if T.GlyphsSetActive then T.GlyphsSetActive(false) end
        local Fb = (T.frame and T.frame.children and T.frame.children["DragonUI_TalentLoadoutsFilter"]) or _G["DragonUI_TalentLoadoutsFilter"]
        if Fb then Fb:Hide() end
        if T.GlyphsApplyPaneVisibility then T.GlyphsApplyPaneVisibility() end
        if T.RefreshSpecTabs then T.RefreshSpecTabs() end
        if T.Refresh then T.Refresh() end
    end)
    reskinSingleTab(name)
    return tab
end

-- Rename cog
local function buildCog()
    local f = T.frame
    if T._specCog then return T._specCog end
    local cog = CreateFrame("Button", "DragonUI_TalentSpecCog", f)
    cog:SetSize(18, 18)
    cog.Icon = cog:CreateTexture(nil, "ARTWORK")
    if not cog.Icon.set_atlas or not cog.Icon:set_atlas("questlog-icon-setting", true) then
        cog.Icon:SetTexture("Interface\\Buttons\\UI-OptionsButton"); cog.Icon:SetSize(16, 16)
    end
    cog.Icon:SetPoint("CENTER")
    cog.Hi = cog:CreateTexture(nil, "HIGHLIGHT")
    if not cog.Hi.set_atlas or not cog.Hi:set_atlas("questlog-icon-setting", true) then
        cog.Hi:SetTexture("Interface\\Buttons\\UI-OptionsButton"); cog.Hi:SetSize(16, 16)
    end
    cog.Hi:SetPoint("CENTER"); cog.Hi:SetBlendMode("ADD"); cog.Hi:SetAlpha(0.4)
    cog:SetFrameLevel((f:GetFrameLevel() or 1) + 10)
    cog:SetPoint("TOPRIGHT", f.bg or f, "TOPRIGHT", -8, -8)
    cog:SetScript("OnClick", function()
        local g = T._viewGroup or 1
        StaticPopup_Show("DUI_TALENT_RENAME_SPEC", nil, nil, { group = g, current = customName(g) or "" })
    end)
    cog:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Rename specialization"] or "Rename specialization", 1, 1, 1)
        GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
    T._specCog = cog
    return cog
end

-- ============================================================================
-- Build-once + update (called from Behavior.Populate and tab clicks)
-- ============================================================================
local function sizeAndAnchorTabs(f, names, opts)
    local x = opts.startX or 14
    local parentPoint = opts.parentPoint or "BOTTOMLEFT"
    for _, n in ipairs(names) do
        local tab = _G[n]
        if tab then
            if tab:IsShown() then
                tab:ClearAllPoints()
                tab:SetPoint("BOTTOMLEFT", f, parentPoint, x, opts.startY or 0)
                x = x + (tab:GetWidth() or 60) + 2
            end
        end
    end
end

function T.RefreshSpecTabs()
    local f = T.frame
    if not f then return end

    if T.IsInspecting and T.IsInspecting() then
        for _, n in ipairs({ TAB_NAMES[1], TAB_NAMES[2], TAB_NAMES[3], TAB_NAMES[4],
                             PET_TAB_NAME, GLYPH_TAB_NAME }) do
            local tab = _G[n]
            if tab then tab:Hide() end
        end
        if T._specCog then T._specCog:Hide() end
        return
    end

    local num = (GetNumTalentGroups and (GetNumTalentGroups() or 1)) or 1

    local hasGlyph = (type(T.GlyphsSetActive) == "function")
    local viewG = T._viewGroup or T._activeGroup or 1
    local glyphActive = T.GlyphsIsActive and T.GlyphsIsActive() or false
    local petAvail    = T.PetHasTalents and T.PetHasTalents() or false
    local petActive   = T.PetViewActive and T.PetViewActive() or false
    local needTalentsTab = hasGlyph or petAvail
    local tabsToSize = {}

    if num >= 2 then
        for g = 1, num do
            local tab = buildTab(g)
            local txt = _G[TAB_NAMES[g] .. "Text"]
            if txt then txt:SetText(specName(g)) elseif tab.SetText then tab:SetText(specName(g)) end
            tab:Show()
            tabsToSize[#tabsToSize + 1] = TAB_NAMES[g]
        end
    else
        local tab = buildTab(1)
        local txt = _G[TAB_NAMES[1] .. "Text"]
        if needTalentsTab then
            local talentsLabel = TALENTS or L["Talents"] or "Talents"
            if txt then txt:SetText(talentsLabel) elseif tab.SetText then tab:SetText(talentsLabel) end
            tab:Show()
            tabsToSize[#tabsToSize + 1] = TAB_NAMES[1]
        else
            if txt then txt:SetText(specName(1)) elseif tab.SetText then tab:SetText(specName(1)) end
            tab:Hide()
        end
        for g = 2, 4 do
            local t2 = _G[TAB_NAMES[g]]
            if t2 then t2:Hide() end
        end
    end

    if petAvail then
        local ptab = buildPetTab()
        local ptxt = _G[PET_TAB_NAME .. "Text"]
        local petLabel = PET or L["Pet"] or "Pet"
        if ptxt then ptxt:SetText(petLabel) elseif ptab.SetText then ptab:SetText(petLabel) end
        ptab:Show()
        tabsToSize[#tabsToSize + 1] = PET_TAB_NAME
    else
        local ptab = _G[PET_TAB_NAME]
        if ptab then ptab:Hide() end
    end

    if hasGlyph then
        local gtab = buildGlyphTab()
        local gtxt = _G[GLYPH_TAB_NAME .. "Text"]
        local glyphLabel = GLYPHS or L["Glyphs"] or "Glyphs"
        if gtxt then gtxt:SetText(glyphLabel) elseif gtab.SetText then gtab:SetText(glyphLabel) end
        gtab:Show()
        tabsToSize[#tabsToSize + 1] = GLYPH_TAB_NAME
    else
        local gtab = _G[GLYPH_TAB_NAME]
        if gtab then gtab:Hide() end
    end

    if #tabsToSize == 0 then
        if T._specCog then T._specCog:Hide() end
        return
    end

    sizeAndAnchorTabs(f, tabsToSize, { startX = 8, startY = -30, parentPoint = "BOTTOMLEFT" })

    local specTurn = (not glyphActive) and (not petActive)
    if num >= 2 then
        for g = 1, num do
            local tab = _G[TAB_NAMES[g]]
            if tab then setTabArt(tab, specTurn and (g == viewG)) end
        end
        if glyphActive or petActive then
            if T._specCog then T._specCog:Hide() end
        else
            buildCog():Show()
        end
    else
        if T._specCog then T._specCog:Hide() end
        local t1 = _G[TAB_NAMES[1]]
        if t1 then setTabArt(t1, specTurn) end
    end

    if petAvail then
        setTabArt(_G[PET_TAB_NAME], petActive)
    end
    if hasGlyph then
        local gtab = _G[GLYPH_TAB_NAME]
        setTabArt(gtab, glyphActive)
    end
end
