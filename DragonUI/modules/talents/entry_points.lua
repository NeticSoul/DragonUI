-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns

local format = string.format

local TOGGLE_NAME = "DragonUI_TalentToggle"

-- Opening and closing -----------------------------------------------------------------------------

local function levelAllows(level)
    if UnitLevel("player") >= level then return true end
    ns.Notify(format(FEATURE_BECOMES_AVAILABLE_AT_LEVEL, level), "gate")
    return false
end

local function talentLevel()
    return SHOW_TALENT_LEVEL or 10
end

local function glyphLevel()
    return SHOW_INSCRIPTION_LEVEL or 15
end

local function freshView()
    ns.viewGroup = ns.ActiveGroup()
    ns.wantPet = false
    ns.SetGlyphPage(false)
end

local function showOrRepaint()
    if ns.win:IsShown() then
        ns.Repaint()
    else
        ns.win:Show()
    end
end

function ns.OpenTalents()
    if not TM.applied or not levelAllows(talentLevel()) then return end
    local wasInspecting = ns.inspectUnit ~= nil
    ns.LeaveInspect()
    if not ns.win:IsShown() then
        freshView()
        ns.win:Show()
    elseif wasInspecting then
        ns.Repaint()
    end
end

function ns.ToggleTalents()
    if not TM.applied then return end
    local win = ns.win
    if win:IsShown() and not ns.inspectUnit and not ns.GlyphView() then
        win:Hide()
        return
    end
    if not levelAllows(talentLevel()) then return end
    ns.LeaveInspect()
    freshView()
    showOrRepaint()
end

function ns.OpenGlyphs()
    if not TM.applied or not levelAllows(glyphLevel()) then return end
    if ns.edit then
        ns.RequestExitEditor()
        if ns.edit then return end
    end
    ns.LeaveInspect()
    ns.viewGroup = ns.ActiveGroup()
    ns.wantPet = false
    ns.SetGlyphPage(true)
    showOrRepaint()
end

function ns.ToggleGlyphs()
    if not TM.applied then return end
    if ns.win:IsShown() and ns.GlyphView() then
        ns.win:Hide()
    else
        ns.OpenGlyphs()
    end
end

_G.SLASH_DRAGONUI_TALENTS1 = "/talents"
SlashCmdList["DRAGONUI_TALENTS"] = function()
    ns.ToggleTalents()
end

-- Key bindings: the stock keys click our hidden button instead of Blizzard's frame ----------------

local bindingOwner, lastBindings

local function rebuildBindings()
    local talentKeys = { GetBindingKey("TOGGLETALENTS") }
    local glyphKeys = { GetBindingKey("TOGGLEINSCRIPTION") }
    local signature = table.concat(talentKeys, ",") .. "|" .. table.concat(glyphKeys, ",")
    if signature == lastBindings then return end
    lastBindings = signature
    ClearOverrideBindings(bindingOwner)
    for _, key in ipairs(talentKeys) do
        SetOverrideBindingClick(bindingOwner, false, key, TOGGLE_NAME, "LeftButton")
    end
    for _, key in ipairs(glyphKeys) do
        SetOverrideBindingClick(bindingOwner, false, key, TOGGLE_NAME, "RightButton")
    end
end

local function queueBindings()
    addon:SafeExecute("talents", "bindings", rebuildBindings)
end

local function buildToggle()
    local toggle = CreateFrame("Button", TOGGLE_NAME, UIParent)
    toggle:Hide()
    toggle:RegisterForClicks("AnyUp")
    toggle:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            ns.ToggleGlyphs()
        else
            ns.ToggleTalents()
        end
    end)
    bindingOwner = CreateFrame("Frame")
end

-- Blizzard's own frames ---------------------------------------------------------------------------

local talentFrameHooked, inspectHooked

-- Hiding it inside its own ShowUIPanel re-enters the panel manager, so wait a frame first.
local function redirectBlizzardFrame()
    addon:After(0, function()
        local frame = PlayerTalentFrame
        if not frame or not frame:IsShown() then return end
        local glyphs = GLYPH_TALENT_TAB and PanelTemplates_GetSelectedTab(frame) == GLYPH_TALENT_TAB
        HideUIPanel(frame)
        if glyphs then
            ns.OpenGlyphs()
        else
            ns.OpenTalents()
        end
    end)
end

local function hookTalentFrame()
    if talentFrameHooked or not PlayerTalentFrame then return end
    talentFrameHooked = true
    PlayerTalentFrame:HookScript("OnShow", redirectBlizzardFrame)
end

local function hookInspect()
    if inspectHooked or not InspectFrame or not InspectFrameTab3 then return end
    inspectHooked = true
    InspectFrameTab3:SetScript("OnClick", function()
        PlaySound("igCharacterInfoTab")
        if InspectFrame.unit then ns.ShowInspect(InspectFrame.unit) end
    end)
    InspectFrame:HookScript("OnHide", function()
        if ns.inspectUnit and ns.win then ns.win:Hide() end
    end)
    hooksecurefunc("InspectFrame_UnitChanged", function()
        if ns.inspectUnit and InspectFrame.unit then ns.ShowInspect(InspectFrame.unit) end
    end)
end

local function onAddonLoaded(_, name)
    if name == "Blizzard_TalentUI" then
        hookTalentFrame()
    elseif name == "Blizzard_InspectUI" then
        hookInspect()
    end
end

-- Entry points ------------------------------------------------------------------------------------

local function installEntryPoints()
    buildToggle()
    queueBindings()
    ns.Listen("UPDATE_BINDINGS", queueBindings)

    -- Blizzard's XML binds the old handler by value, so the script itself has to be replaced.
    if TalentMicroButton then
        TalentMicroButton:SetScript("OnClick", function() ns.ToggleTalents() end)
    end
    hooksecurefunc("UpdateMicroButtons", function()
        if ns.win and ns.win:IsShown() and TalentMicroButton then
            TalentMicroButton:SetButtonState("PUSHED", 1)
        end
    end)

    UIParent:UnregisterEvent("USE_GLYPH")
    ns.Listen("USE_GLYPH", function() ns.OpenGlyphs() end)

    ns.Listen("ADDON_LOADED", onAddonLoaded)
    if IsAddOnLoaded("Blizzard_TalentUI") then hookTalentFrame() end
    if IsAddOnLoaded("Blizzard_InspectUI") then hookInspect() end
end

local function rescale()
    if TM.applied then ns.ApplyScale() end
end

local function installEvents()
    ns.InstallLiveEvents()
    ns.InstallGlyphEvents()
    ns.InstallOrbEvents()
    ns.InstallSharing()
    ns.Listen("UI_SCALE_CHANGED", function()
        rescale()
        ns.PlaceCatcher()
    end)
    ns.Listen("DISPLAY_SIZE_CHANGED", rescale)
end

-- Lifecycle ---------------------------------------------------------------------------------------

local function apply()
    if TM.applied or not IsLoggedIn() or not addon:IsModuleEnabled("talents") then return end
    ns.BuildWindow()
    TM.initialized = true
    TM.applied = true
    installEntryPoints()
    installEvents()
end

function addon.ApplyTalentSystem()
    apply()
end

function addon.RefreshTalentSystem()
    apply()
    if not TM.applied then return end
    ns.ApplyScale()
    if ns.win:IsShown() then ns.Repaint() end
end

-- Load-once: the hooks live until reload, so a mid-session disable deliberately changes nothing.
function addon.RestoreTalentSystem()
end

ns.Listen("PLAYER_LOGIN", apply)
