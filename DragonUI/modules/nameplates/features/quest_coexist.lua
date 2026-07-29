-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
local addon = select(2, ...)
local NP = addon.Nameplates
local C = NP.const

NP.quest_coexist = NP.quest_coexist or {}

-- Localized string with English fallback (addon.L may not be ready when this file loads).
local function T(s)
    local L = addon.L
    return (L and L[s]) or s
end

-- Y-offset from screen top; tweak so the popup clears Questie's initial minimap prompt.
local ANCHOR_Y = -180

local popup

-- Check the Questie global, not IsAddOnLoaded: the addon name follows the folder (e.g. "Questie-335").
local function IsQuestieShowingNameplates()
    return Questie and Questie.db and Questie.db.profile
        and Questie.db.profile.nameplateEnabled == true or false
end
NP.quest_coexist.IsQuestieShowingNameplates = IsQuestieShowingNameplates

-- Questie fully initialized: the flag it sets at the very end of QuestieInit, after the DB compiles.
local function IsQuestieReady()
    return Questie and Questie.started == true or false
end

-- Cede to Questie by default (avoids duplicate icons) until the user explicitly picks DragonUI.
function NP.quest_coexist.ShouldDeferToQuestie()
    local q = NP.config.GetCfg().questIcons
    if not q or q.questieCoexist == "dragonui" then return false end
    return IsQuestieShowingNameplates()
end

StaticPopupDialogs["DRAGONUI_QUEST_COEXIST_RELOAD"] = {
    text = "Applying quest icon settings needs a UI reload.",
    button1 = "Reload",
    button2 = "Later",
    OnAccept = function() ReloadUI() end,
    timeout = 0,
    whileDead = true,
    hideOnEscape = true,
}

-- dragonui -> turn Questie's icons OFF; questie -> turn them ON; ask -> leave as-is.
-- Questie registers those hooks at load, so any change to nameplateEnabled needs a reload.
function NP.quest_coexist.ApplyChoice(choice)
    local q = NP.config.GetCfg().questIcons
    if q then q.questieCoexist = choice end
    if popup then popup:Hide() end

    local want
    if choice == "dragonui" then want = false
    elseif choice == "questie" then want = true end

    local qdb = Questie and Questie.db and Questie.db.profile
    if qdb and want ~= nil and qdb.nameplateEnabled ~= want then
        qdb.nameplateEnabled = want
        -- Localize the dialog now (addon.L is ready at runtime, unlike at load time).
        local d = StaticPopupDialogs["DRAGONUI_QUEST_COEXIST_RELOAD"]
        d.text = T("Applying quest icon settings needs a UI reload.")
        d.button1 = T("Reload")
        d.button2 = T("Later")
        StaticPopup_Show("DRAGONUI_QUEST_COEXIST_RELOAD")
        return
    end
    if NP.engine and NP.engine.QueueMass and NP.engine.Callbacks then
        NP.engine.QueueMass(NP.engine.Callbacks.OnUpdateQuest)
    end
end
local ApplyChoice = NP.quest_coexist.ApplyChoice

-- DragonUI's flat "options panel" look, so the wizard matches the rest of the addon.
local ASSETS = "Interface\\AddOns\\DragonUI\\Textures\\"
local FLAT = "Interface\\ChatFrame\\ChatFrameBackground"
local ACCENT = { 0.11, 0.55, 0.85 }
local GOLD = { 1.0, 0.82, 0.0 }
local DIM = { 0.72, 0.72, 0.72 }

local function FlatBackdrop(frame, r, g, b, a, br, bg, bb)
    frame:SetBackdrop({ bgFile = FLAT, edgeFile = FLAT, tile = false, edgeSize = 1 })
    frame:SetBackdropColor(r, g, b, a)
    frame:SetBackdropBorderColor(br or 0.28, bg or 0.28, bb or 0.32, 1)
end

-- Flat text button; primary = accent border + white text.
local function MakeButton(parent, w, label, primary, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 26)
    FlatBackdrop(b, 0.16, 0.16, 0.18, 1)
    if primary then b:SetBackdropBorderColor(ACCENT[1], ACCENT[2], ACCENT[3], 1) end
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetTexture(FLAT)
    hl:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.3)
    local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("CENTER")
    fs:SetText(label)
    if primary then fs:SetTextColor(1, 1, 1) end
    b:SetScript("OnClick", onClick)
    return b
end

-- Icon selector using DragonUI's action-bar icon frame (rounds off any icon, sword included).
local function MakeSelector(parent, x, y, iconTex, mirror, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(38, 38)
    b:SetPoint("TOPLEFT", x, y)
    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetSize(26, 26)
    icon:SetPoint("CENTER")
    icon:SetTexture(iconTex)
    if mirror then icon:SetTexCoord(1, 0, 0, 1) end -- sword is mirrored on the plate too
    local frameTex = b:CreateTexture(nil, "OVERLAY")
    frameTex:SetAllPoints()
    frameTex:SetTexture(ASSETS .. "ActionBars\\uiactionbariconframe")
    local selTex = b:CreateTexture(nil, "OVERLAY")
    selTex:SetAllPoints()
    selTex:SetTexture(ASSETS .. "ActionBars\\uiactionbariconframehighlight")
    selTex:Hide()
    b.icon, b.selTex = icon, selTex
    b:SetScript("OnClick", onClick)
    return b
end

-- Wizard state (chosen DragonUI icon style); seeded from config when the popup is built.
local sel = { kill = "sword", loot = "bag", pointer = false }
local dimGroups = {}

-- Pointer mode overrides kill/loot, so grey those controls when it's on.
local function SetGroupDimmed(dimmed)
    for i = 1, #dimGroups do
        dimGroups[i]:SetAlpha(dimmed and 0.35 or 1)
    end
end

-- Mutually-exclusive icon selectors writing sel[field]; picked one glows, others dim.
local function MakeIconGroup(parent, x, y, keys, field)
    local buttons = {}
    local function refresh()
        for key, b in pairs(buttons) do
            if sel[field] == key then
                b.selTex:Show()
                b.icon:SetVertexColor(1, 1, 1)
            else
                b.selTex:Hide()
                b.icon:SetVertexColor(0.5, 0.5, 0.5)
            end
        end
    end
    for i = 1, #keys do
        local key = keys[i]
        local b = MakeSelector(parent, x + (i - 1) * 44, y, C.QUEST_ICON_TEX[key], key == "sword",
            function() sel[field] = key; refresh() end)
        buttons[key] = b
        dimGroups[#dimGroups + 1] = b
    end
    refresh()
end

local function SectionLabel(parent, text, x, y, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fs:SetPoint("TOPLEFT", x, y)
    fs:SetText(text)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function BuildPopup()
    if popup then return popup end

    local q = NP.config.GetCfg().questIcons or {}
    sel.kill = (q.killIcon == "skull") and "skull" or "sword"
    sel.loot = (q.lootIcon == "chest") and "chest" or "bag"
    sel.pointer = q.pointerMode == true

    local f = CreateFrame("Frame", "DragonUIQuestCoexist", UIParent)
    f:SetSize(404, 224)
    f:SetPoint("TOP", UIParent, "TOP", 0, ANCHOR_Y)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    tinsert(UISpecialFrames, "DragonUIQuestCoexist") -- ESC postpones; reappears next login until chosen
    FlatBackdrop(f, 0.06, 0.06, 0.08, 0.97)

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -14)
    title:SetText(T("Quest Icons on Nameplates"))
    title:SetTextColor(GOLD[1], GOLD[2], GOLD[3])

    local desc = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    desc:SetPoint("TOP", title, "BOTTOM", 0, -6)
    desc:SetWidth(360)
    desc:SetText(T("Which quest icons do you want on your nameplates?"))
    desc:SetTextColor(DIM[1], DIM[2], DIM[3])

    SectionLabel(f, "DRAGONUI", 22, -64, ACCENT)

    dimGroups[#dimGroups + 1] = SectionLabel(f, T("Kill"), 34, -92)
    MakeIconGroup(f, 66, -84, { "sword", "skull" }, "kill")
    dimGroups[#dimGroups + 1] = SectionLabel(f, T("Loot"), 196, -92)
    MakeIconGroup(f, 238, -84, { "bag", "chest" }, "loot")

    -- Custom flat checkbox: UICheckButtonTemplate's art never squares off cleanly.
    local cb = CreateFrame("Button", nil, f)
    cb:SetPoint("TOPLEFT", 32, -136)
    cb:SetSize(16, 16)
    FlatBackdrop(cb, 0.14, 0.14, 0.16, 1)
    local cbCheck = cb:CreateTexture(nil, "OVERLAY")
    cbCheck:SetPoint("CENTER")
    cbCheck:SetSize(18, 18)
    cbCheck:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
    if not sel.pointer then cbCheck:Hide() end
    local cbHl = cb:CreateTexture(nil, "HIGHLIGHT")
    cbHl:SetAllPoints()
    cbHl:SetTexture(FLAT)
    cbHl:SetVertexColor(ACCENT[1], ACCENT[2], ACCENT[3], 0.25)
    local pIcon = f:CreateTexture(nil, "ARTWORK")
    pIcon:SetSize(26, 26)
    pIcon:SetPoint("LEFT", cb, "RIGHT", 6, 2)
    pIcon:SetTexture(C.QUEST_ICON_TEX.pointer)
    local cbLabel = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cbLabel:SetPoint("LEFT", pIcon, "RIGHT", -10, -2) -- pointer texture has right-side padding; pull text in
    cbLabel:SetText(T('Pointer mode (just "!")'))
    cb:SetScript("OnClick", function()
        sel.pointer = not sel.pointer
        if sel.pointer then cbCheck:Show() else cbCheck:Hide() end
        SetGroupDimmed(sel.pointer)
    end)

    local useDui = MakeButton(f, 116, T("Use DragonUI"), true, function()
        local cfg = NP.config.GetCfg().questIcons
        if cfg then cfg.killIcon, cfg.lootIcon, cfg.pointerMode = sel.kill, sel.loot, sel.pointer end
        ApplyChoice("dragonui")
    end)
    useDui:SetPoint("TOPRIGHT", -20, -136)

    local sep = f:CreateTexture(nil, "ARTWORK")
    sep:SetTexture(1, 1, 1, 0.10)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 22, -172)
    sep:SetPoint("TOPRIGHT", -22, -172)

    SectionLabel(f, "QUESTIE", 22, -186, ACCENT)
    local qicons = (Questie and Questie.icons) or {}
    local qslay = f:CreateTexture(nil, "ARTWORK")
    qslay:SetSize(22, 22)
    qslay:SetPoint("TOPLEFT", 96, -184)
    qslay:SetTexture(qicons.slay or "Interface\\GossipFrame\\ActiveQuestIcon")
    if qicons.loot then
        local qloot = f:CreateTexture(nil, "ARTWORK")
        qloot:SetSize(22, 22)
        qloot:SetPoint("TOPLEFT", 126, -184)
        qloot:SetTexture(qicons.loot)
    end

    local useQ = MakeButton(f, 116, T("Use Questie"), false, function() ApplyChoice("questie") end)
    useQ:SetPoint("TOPRIGHT", -20, -182)

    SetGroupDimmed(sel.pointer)

    popup = f
    return f
end

-- Wait for Questie.started, rebuild for loot, then offer the wizard once its tutorial closes.
local watcher
local function StartWatcher()
    if watcher then return end
    watcher = CreateFrame("Frame")
    local tick, waited, rebuilt = 0, 0, false
    watcher:SetScript("OnUpdate", function(self, e)
        tick = tick + e
        if tick < 1 then return end
        waited, tick = waited + tick, 0
        if waited > 180 or not (Questie or QuestieLoader) then
            self:SetScript("OnUpdate", nil)
            watcher = nil
            return
        end
        if not IsQuestieReady() then return end
        -- Questie is up: rebuild once so loot resolves, even before/without the wizard.
        if not rebuilt then
            rebuilt = true
            if NP.quest and NP.quest.OnQuestLogChanged then NP.quest.OnQuestLogChanged() end
        end
        local q = NP.config.GetCfg().questIcons
        if not q or q.enabled ~= true or q.questieCoexist ~= "ask" then
            self:SetScript("OnUpdate", nil)
            watcher = nil
            return
        end
        -- Don't overlap Questie's welcome tutorial: hold until the user dismisses it.
        local tut = _G.QuestieTutorialChooseObjectiveType
        if tut and tut.IsShown and tut:IsShown() then return end
        self:SetScript("OnUpdate", nil)
        watcher = nil
        BuildPopup():Show()
    end)
end

-- Re-offer on profile change/reset: questieCoexist may return to "ask" with no PLAYER_ENTERING_WORLD.
local profileHooked
local function EnsureProfileHook()
    if profileHooked or not (addon.db and addon.db.RegisterCallback) then return end
    profileHooked = true
    local function onProfile() NP.quest_coexist.Check() end
    addon.db.RegisterCallback(NP.quest_coexist, "OnProfileChanged", onProfile)
    addon.db.RegisterCallback(NP.quest_coexist, "OnProfileReset", onProfile)
    addon.db.RegisterCallback(NP.quest_coexist, "OnProfileCopied", onProfile)
end

-- Wait for Questie to finish loading, then rebuild (loot) and offer the wizard if undecided.
function NP.quest_coexist.Check()
    EnsureProfileHook()
    local q = NP.config.GetCfg().questIcons
    if not q or q.enabled ~= true then return end
    if not (Questie or QuestieLoader) then return end
    StartWatcher()
end
