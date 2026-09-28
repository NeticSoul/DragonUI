-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns
local L = addon.L

local bar = {}

local function redButton(name, parent, width, label)
    local button = CreateFrame("Button", name, parent, "UIPanelButtonTemplate")
    button:SetSize(width, 22)
    if label then button:SetText(label) end
    return button
end

local function setEnabled(button, on)
    if on then button:Enable() else button:Disable() end
end

-- Search box --------------------------------------------------------------------------------------

local function syncHint(box)
    bar.hint:SetShownCompat(box:GetText() == "")
end

local function buildSearch(footer, after)
    local box = CreateFrame("EditBox", "DragonUI_TalentSearchBox", footer, "InputBoxTemplate")
    box:SetSize(184, 22)
    box:SetAutoFocus(false)
    box:SetTextInsets(18, 6, 0, 0)
    box:SetPoint("LEFT", after, "RIGHT", 20, 0)

    local glass = box:CreateTexture(nil, "OVERLAY")
    glass:SetTexture(addon._dir .. "Collections\\UI-Searchbox-Icon")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", box, "LEFT", 2, -1.5)

    local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", box, "LEFT", 20, 0)
    hint:SetText(L["Search talents"])
    bar.hint = hint

    box:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    box:HookScript("OnEditFocusGained", function() hint:Hide() end)
    box:HookScript("OnEditFocusLost", syncHint)
    box:SetScript("OnTextChanged", function(self)
        local query = self:GetText():lower()
        if query ~= ns.query then
            ns.query = query
            ns.ApplySearch()
        end
        syncHint(self)
    end)
    bar.search = box
    return box
end

-- Apply, activate, reset and undo -----------------------------------------------------------------

local function applyClicked()
    if ns.edit then
        ns.Call("SaveBuild", ns.edit)
    else
        StaticPopup_Show("DUI_TALENTS_LEARN")
    end
end

local function buildApply(footer, after)
    local apply = redButton("DragonUI_TalentApplyButton", footer, 150, L["Apply Changes"])
    apply:SetPoint("LEFT", after, "RIGHT", 24, 0)
    apply:SetScript("OnClick", applyClicked)
    apply:SetScript("OnEnter", function(self)
        if not ns.edit then ns.Tip(self, nil, { TALENT_TOOLTIP_LEARNTALENTGROUP, 1, 1, 1, true }) end
    end)
    apply:SetScript("OnLeave", GameTooltip_Hide)
    if addon.SkinRedButton then addon.SkinRedButton(apply) end

    local glow = footer:CreateTexture(nil, "ARTWORK")
    glow:SetTexture("Interface\\Buttons\\UI-Panel-Button-Glow")
    glow:SetTexCoord(0, 0.75, 0, 0.609375)
    glow:SetBlendMode("ADD")
    glow:SetVertexColor(0.2, 1, 0.2)
    glow:SetPoint("TOPLEFT", apply, "TOPLEFT", -11, 7)
    glow:SetPoint("BOTTOMRIGHT", apply, "BOTTOMRIGHT", 11, -7)
    glow:SetAlpha(0.35)
    glow:Hide()
    local bounce = glow:CreateAnimationGroup()
    local swell = bounce:CreateAnimation("Alpha")
    swell:SetDuration(0.8)
    swell:SetChange(0.65)
    swell:SetSmoothing("IN_OUT")
    bounce:SetLooping("BOUNCE")
    glow.bounce = bounce

    bar.apply, bar.applyGlow = apply, glow
    return apply
end

local function refreshActivate(button)
    local spells = TALENT_ACTIVATION_SPELLS
    local spell = spells and spells[ns.viewGroup]
    setEnabled(button, not (spell and IsCurrentSpell(spell)))
end

local function buildActivate(footer, apply)
    local activate = redButton("DragonUI_TalentActivateButton", footer, 100, TALENT_SPEC_ACTIVATE)
    activate:SetWidth(activate:GetTextWidth() + 40)
    activate:SetPoint("LEFT", apply, "LEFT", 0, 0)
    activate:SetScript("OnClick", function() SetActiveTalentGroup(ns.viewGroup) end)
    activate:SetScript("OnShow", function(self)
        self:RegisterEvent("CURRENT_SPELL_CAST_CHANGED")
        refreshActivate(self)
    end)
    activate:SetScript("OnHide", function(self) self:UnregisterEvent("CURRENT_SPELL_CAST_CHANGED") end)
    activate:SetScript("OnEvent", refreshActivate)
    activate:SetShownCompat(false)
    if addon.SkinRedButton then addon.SkinRedButton(activate) end
    bar.activate = activate
end

local function iconControl(footer, atlas, anchor, gap, tip, onClick)
    local art = footer:CreateTexture(nil, "ARTWORK")
    art:SetAtlasTexture(atlas, true)
    art:SetPoint("LEFT", anchor, "RIGHT", gap, 0)
    local hit = CreateFrame("Button", nil, footer)
    hit:SetSize(25, 25)
    hit:SetPoint("CENTER", art, "CENTER", 0, 0)
    hit:SetScript("OnClick", onClick)
    hit:SetScript("OnEnter", function(self) ns.Tip(self, nil, { tip(), 1, 1, 1 }) end)
    hit:SetScript("OnLeave", GameTooltip_Hide)
    hit.art = art
    return hit
end

-- Editor and inspect buttons ----------------------------------------------------------------------

local function buildModeButtons(footer, apply)
    local exit = redButton("DragonUI_TalentEditExit", footer, 100, L["Exit Editor"])
    exit:SetPoint("LEFT", apply, "RIGHT", 8, 0)
    exit:SetScript("OnClick", function() ns.Call("RequestExitEditor") end)
    exit:SetScript("OnEnter", function(self)
        ns.TitledTip(self, L["Exit Editor"], L["Back to your live talents. Saved builds keep every change."])
    end)
    exit:SetScript("OnLeave", GameTooltip_Hide)
    exit:Hide()
    if addon.SkinRedButton then addon.SkinRedButton(exit) end

    local import = redButton("DragonUI_TalentInspectImport", footer, 180, L["Import to My Profiles"])
    import:SetPoint("CENTER", footer, "CENTER", 0, 1)
    import:SetScript("OnClick", function() ns.Call("ImportFromInspect") end)
    import:SetScript("OnEnter", function(self)
        ns.TitledTip(self, L["Import to My Profiles"], L["Save this build to your talent profiles."])
    end)
    import:SetScript("OnLeave", GameTooltip_Hide)
    import:Hide()
    if addon.SkinRedButton then addon.SkinRedButton(import) end

    bar.exit, bar.import = exit, import
end

function ns.BuildFooterControls(footer)
    local dropdown = ns.Call("BuildDropdown", footer)
    dropdown:SetPoint("LEFT", footer, "LEFT", 14, 0)
    bar.dropdown = dropdown

    local search = buildSearch(footer, dropdown)
    local apply = buildApply(footer, search)
    buildActivate(footer, apply)

    bar.reset = iconControl(footer, "talents-button-reset", apply, 14,
        function() return TALENT_TOOLTIP_RESETTALENTGROUP end, function() ns.ResetView() end)
    bar.undo = iconControl(footer, "talents-button-undo", bar.reset.art, 8,
        function() return L["Undo the last point"] end, function() ns.UndoLast() end)

    local points = footer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    points:SetJustifyH("LEFT")
    bar.points = points

    buildModeButtons(footer, apply)
end

function ns.SetPointsText(text)
    if bar.points then bar.points:SetText(text) end
end

-- Visibility per mode -----------------------------------------------------------------------------

local function showIcon(hit, shown, enabled)
    hit:SetShownCompat(shown)
    hit.art:SetShownCompat(shown)
    setEnabled(hit, enabled)
    hit.art:SetDesaturated(not enabled)
end

function ns.UpdateFooter()
    if not bar.apply then return end
    local inspect = ns.inspectUnit ~= nil
    local glyph = ns.GlyphView()
    local edit = ns.edit ~= nil
    local pet = ns.PetView()
    local browsing = ns.Browsing()
    local live = ns.LiveMode()
    local ctx = ns.ViewContext()
    local staged = not edit and ns.StagedPoints(ctx) > 0

    local apply = bar.apply
    apply:SetText(edit and L["Save Build"] or L["Apply Changes"])
    apply:SetShownCompat(live)
    setEnabled(apply, edit or staged)

    local glow = bar.applyGlow
    if live and staged then
        glow:Show()
        if not glow.bounce:IsPlaying() then glow.bounce:Play() end
    else
        glow.bounce:Stop()
        glow:Hide()
    end

    local icons = live and not edit
    showIcon(bar.reset, icons, staged)
    showIcon(bar.undo, icons, staged and ns.UndoDepth(ctx) > 0)

    bar.activate:SetShownCompat(browsing)
    if browsing then refreshActivate(bar.activate) end

    local points = bar.points
    points:ClearAllPoints()
    if edit then
        points:SetPoint("LEFT", bar.exit, "RIGHT", 16, 0)
    else
        points:SetPoint("LEFT", bar.undo.art, "RIGHT", 16, 0)
    end
    points:SetShownCompat(live)

    bar.exit:SetShownCompat(edit)
    bar.import:SetShownCompat(inspect)
    bar.dropdown:SetShownCompat(live and not pet)
    bar.search:SetShownCompat(live or browsing)

    ns.Call("ShowOrb", not inspect and not glyph and not edit)
    ns.Call("UpdateSpecCog")
    ns.Call("UpdateGlyphSwitch")
    ns.Call("PlaceCatcher")
end
