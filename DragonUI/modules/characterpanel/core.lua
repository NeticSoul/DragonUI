-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local CharacterPanelModule = { initialized = false, applied = false }
addon.CharacterPanel = addon.CharacterPanel or {}
local CP = addon.CharacterPanel

-- No PetPaperDollFrame: petpane.lua pins it shut and takes over its tab, so it can never be the
-- active tab. It stays in Blizzard's own CHARACTERFRAME_SUBFRAMES, which is what keeps it hidden.
CP.SUBFRAMES = {
    "PaperDollFrame", "DragonUIPetFrame", "SkillFrame", "ReputationFrame", "TokenFrame",
    "DragonUIHonorFrame",
}

-- Tabs whose contents we draw ourselves, so they get the retail frame and Blizzard's own widgets
-- are hidden wholesale. Everything else keeps Blizzard's layout and window size.
CP.OWNED_TABS = {
    PaperDollFrame = true,
    DragonUIPetFrame = true,
    SkillFrame = true,
    ReputationFrame = true,
    TokenFrame = true,
    DragonUIHonorFrame = true,
}

-- Retail PANEL_DEFAULT_WIDTH/HEIGHT. The weapon row sits beside the columns, so 424 fits once Ammo
-- is out of the row. Only PaperDoll uses these; the other tabs keep Blizzard's dimensions.
CP.PANEL_WIDTH = 338
CP.PANEL_HEIGHT = 424
-- The list tabs run full width with no sidebar. 338 is narrower than the tab strip itself, which
-- is why the tabs overhung the frame there; this is the reference's width for the same tabs.
CP.LIST_WIDTH = 430
CP.VANILLA_WIDTH = 384
CP.VANILLA_HEIGHT = 512

-- Levels above CharacterFrame the tab subframes get raised to, so the Inset's backdrop renders
-- between the frame's rock texture and the tab contents instead of on top of them.
CP.SUBFRAME_LEVEL = 10

if addon.RegisterModule then
    addon:RegisterModule("characterpanel", CharacterPanelModule,
        addon.L["Character Panel"],
        addon.L["Retail-style character window with a modern frame, class portrait and stats sidebar"],
        { lifecyclePrefix = "CharacterPanel", loadOnce = true })
end

function CP:Config()
    return addon:GetModuleConfig("characterpanel") or {}
end

function CP:Enabled()
    return addon:IsModuleEnabled("characterpanel")
end

-- Asked rather than assumed: honorpane moves the secure companion buttons out of the window's tree,
-- which is the only thing that made it protected, so resizing is free unless they ever come back.
function CP:CanLayout()
    local cf = _G.CharacterFrame
    return cf and not (InCombatLockdown() and cf:IsProtected())
end

-- Every builder registers here; boot runs them in order once CharacterFrame exists.
CP._builders = {}

function CP:RegisterBuilder(name, fn)
    self._builders[#self._builders + 1] = { name = name, fn = fn }
end

local function runBuilders()
    if not _G.CharacterFrame then return end
    for _, b in ipairs(CP._builders) do
        local ok, err = pcall(b.fn)
        if not ok then
            addon:Error("CharacterPanel builder '" .. b.name .. "' failed: " .. tostring(err))
        end
    end
end

-- Reskin ops are all texture/anchor writes on an unprotected frame, but resizing while the
-- UIPanel manager is mid-layout in combat still jitters — defer the whole pass.
local function applySafely()
    if InCombatLockdown() then
        addon.CombatQueue:Add("characterpanel_apply", runBuilders)
        return
    end
    runBuilders()
end

CP.Apply = applySafely

local function ApplyCharacterPanelSystem()
    if not CP:Enabled() then return end
    CharacterPanelModule.initialized = true
    CharacterPanelModule.applied = true
    applySafely()
end

local function RestoreCharacterPanelSystem()
    CharacterPanelModule.applied = false
    -- Before RestoreChrome: putting the sidebar away frees the width that restore then settles.
    if CP.RestoreSidebar then CP.RestoreSidebar() end
    if CP.RestorePortrait then CP.RestorePortrait() end
    if CP.RestoreLevelText then CP.RestoreLevelText() end
    if CP.RestoreModelControls then CP.RestoreModelControls() end
    if CP.RestoreModel then CP.RestoreModel() end
    if CP.RestoreChrome then CP.RestoreChrome() end
    -- Last: it hands a replacement paperdoll its own widgets back, over the geometry we just undid.
    if CP.RestoreCompatHD then CP.RestoreCompatHD() end
    addon:Print(addon.L["Character Panel restored. Reload the UI for a fully clean state."])
end

addon.ApplyCharacterPanelSystem = ApplyCharacterPanelSystem
addon.RestoreCharacterPanelSystem = RestoreCharacterPanelSystem

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
-- Blizzard_TokenUI is LoadOnDemand, so TokenFrame does not exist until the player first
-- opens the Currency tab; without this it never gets the reskin.
boot:RegisterEvent("ADDON_LOADED")
boot:SetScript("OnEvent", function(_, event, name)
    if not CP:Enabled() then return end
    if event == "ADDON_LOADED" and name ~= "Blizzard_TokenUI" then return end
    CharacterPanelModule.initialized = true
    CharacterPanelModule.applied = true
    applySafely()
end)
