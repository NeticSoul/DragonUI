-- Apply/restore lifecycle, profile-change handling, init events, slash commands, addon.* exports.
local addon = select(2, ...)
local mod = addon.BagsterModule

-- ============================================================================
-- APPLY / RESTORE SYSTEM
-- ============================================================================

local AutoShowInventory, AutoHideInventory

local function HideBlizzardKeyring()
    local index = IsBagOpen(KEYRING_CONTAINER)
    if index then
        local frame = _G["ContainerFrame" .. index]
        if frame then
            frame:Hide()
        end
    end
end

-- Light backpack + bag slots + keyring on the micromenu while Bagster inventory is open.
local function IsBagsterInventoryShown()
    if not mod.frames then return false end
    for _, frame in pairs(mod.frames) do
        if frame and not frame.isBank and frame.IsShown and frame:IsShown() then
            return true
        end
    end
    return false
end

local function HighlightMainMenuBags()
    local active = IsBagsterInventoryShown() and 1 or nil
    local buttons = {
        _G.MainMenuBarBackpackButton,
        _G.CharacterBag0Slot,
        _G.CharacterBag1Slot,
        _G.CharacterBag2Slot,
        _G.CharacterBag3Slot,
        _G.KeyRingButton,
    }
    for i = 1, #buttons do
        local button = buttons[i]
        if button then
            button:SetChecked(active)
        end
    end
end

-- CheckButtons toggle checked on click after OnClick; re-assert next frame
local highlightBagsDriver
local function ScheduleHighlightMainMenuBags()
    if not highlightBagsDriver then
        highlightBagsDriver = CreateFrame("Frame")
    end
    highlightBagsDriver:SetScript("OnUpdate", function(self)
        self:SetScript("OnUpdate", nil)
        HighlightMainMenuBags()
    end)
end

-- Kept for micromenu / older call sites
local function SyncKeyRingChecked()
    ScheduleHighlightMainMenuBags()
end

local function ApplyBagsterSystem()
    if mod.BagsterModule.applied then return end

    mod.SetupDatabase()
    if not mod.DB then return end

    -- Sets are empty by default (no category tabs shown)
    -- Users can enable individual tabs via the options panel

    -- Create frames only once; toggling module should reuse existing frames.
    mod.frames = mod.frames or {}
    if not mod.frames[1] then
        mod.frames[1] = mod.Frame:New(mod.L.InventoryTitle, mod.DB.inventory, false, "inventory")
    end
    if not mod.frames[2] then
        mod.frames[2] = mod.Frame:New(mod.L.BankTitle, mod.DB.bank, true, "bank")
    end

    -- Apply retail skin to frames (independent of bags_skin module)
    mod.BagsterApplySkin()

    AutoShowInventory = function()
        mod:Show(BACKPACK_CONTAINER, true)
    end
    AutoHideInventory = function()
        mod:Hide(BACKPACK_CONTAINER, true)
    end

    mod.BagsterModule.originalStates.OpenBackpack = _G.OpenBackpack
    mod.BagsterModule.originalStates.ToggleBank = _G.ToggleBank
    mod.BagsterModule.originalStates.ToggleBackpack = _G.ToggleBackpack
    mod.BagsterModule.originalStates.OpenAllBags = _G.OpenAllBags
    mod.BagsterModule.originalStates.ToggleAllBags = _G.ToggleAllBags
    mod.BagsterModule.originalStates.ToggleBag = _G.ToggleBag
    mod.BagsterModule.originalStates.ToggleKeyRing = _G.ToggleKeyRing

    -- Hook bag functions
    _G.OpenBackpack = AutoShowInventory
    if not mod.BagsterModule.hooks.closeBackpack then
        hooksecurefunc("CloseBackpack", AutoHideInventory)
        mod.BagsterModule.hooks.closeBackpack = true
    end

    _G.ToggleBank = function(bag) mod:Toggle(bag) end
    _G.ToggleBackpack = function()
        mod:Toggle(BACKPACK_CONTAINER)
        ScheduleHighlightMainMenuBags()
    end
    _G.ToggleBag = function(slot)
        if slot == BACKPACK_CONTAINER then
            mod:Toggle(BACKPACK_CONTAINER)
        else
            mod:Toggle(slot)
        end
        ScheduleHighlightMainMenuBags()
    end
    -- Keyring lives inside Bagster inventory; never open stock ContainerFrame
    _G.ToggleKeyRing = function()
        if IsOptionFrameOpen and IsOptionFrameOpen() then
            return
        end
        HideBlizzardKeyring()
        mod:Toggle(KEYRING_CONTAINER)
        ScheduleHighlightMainMenuBags()
    end
    -- Some keybind paths call OpenAllBags directly, so make it a true toggle.
    _G.OpenAllBags = function()
        mod:Toggle(BACKPACK_CONTAINER)
        ScheduleHighlightMainMenuBags()
    end
    if _G.ToggleAllBags then
        _G.ToggleAllBags = function()
            mod:Toggle(BACKPACK_CONTAINER)
            ScheduleHighlightMainMenuBags()
        end
    end

    if not mod.BagsterModule.hooks.closeAllBags then
        hooksecurefunc("CloseAllBags", function()
            mod:Hide(BACKPACK_CONTAINER)
            ScheduleHighlightMainMenuBags()
        end)
        mod.BagsterModule.hooks.closeAllBags = true
    end

    -- Stock BagSlotButton_UpdateChecked uses IsBagOpen(ContainerFrame) and clears the clicked bag
    if not mod.BagsterModule.hooks.bagSlotHighlight then
        if _G.BagSlotButton_OnClick then
            hooksecurefunc("BagSlotButton_OnClick", ScheduleHighlightMainMenuBags)
        end
        if _G.BagSlotButton_OnModifiedClick then
            hooksecurefunc("BagSlotButton_OnModifiedClick", ScheduleHighlightMainMenuBags)
        end
        if _G.BackpackButton_OnClick then
            hooksecurefunc("BackpackButton_OnClick", ScheduleHighlightMainMenuBags)
        end
        if _G.BackpackButton_OnModifiedClick then
            hooksecurefunc("BackpackButton_OnModifiedClick", ScheduleHighlightMainMenuBags)
        end
        if _G.BagSlotButton_UpdateChecked then
            hooksecurefunc("BagSlotButton_UpdateChecked", ScheduleHighlightMainMenuBags)
        end
        if _G.BackpackButton_UpdateChecked then
            hooksecurefunc("BackpackButton_UpdateChecked", ScheduleHighlightMainMenuBags)
        end
        mod.BagsterModule.hooks.bagSlotHighlight = true
    end

    HideBlizzardKeyring()
    HighlightMainMenuBags()
    BankFrame:UnregisterAllEvents()
    BankFrame:Hide()

    -- The stock guild vault is load-on-demand; blanking its loader keeps it from ever existing
    if mod.BagsterModule.originalStates.GuildBankFrame_LoadUI == nil then
        mod.BagsterModule.originalStates.GuildBankFrame_LoadUI = _G.GuildBankFrame_LoadUI
    end
    _G.GuildBankFrame_LoadUI = function() end
    if _G.GuildBankFrame then
        GuildBankFrame:UnregisterAllEvents()
        GuildBankFrame:Hide()
    end

    if not mod.BagsterModule.hooks.inventoryEvents then
        mod("InventoryEvents"):Register(mod, "BANK_OPENED", function()
            mod:Show(BANK_CONTAINER, true)
            mod:Show(BACKPACK_CONTAINER, true)
        end)
        mod("InventoryEvents"):Register(mod, "BANK_CLOSED", function()
            mod:Hide(BANK_CONTAINER, true)
            mod:Hide(BACKPACK_CONTAINER, true)
        end)
        mod.BagsterModule.hooks.inventoryEvents = true
    end

    -- Auto show/hide on trade/auction/mail
    local autoEventFrame = mod.BagsterModule.frames.autoEventFrame or CreateFrame("Frame")
    autoEventFrame:UnregisterAllEvents()
    autoEventFrame:SetScript("OnEvent", function(self, event)
        if event == "MAIL_CLOSED" or event == "TRADE_CLOSED" or
           event == "TRADE_SKILL_CLOSE" or event == "AUCTION_HOUSE_CLOSED" then
            AutoHideInventory()
        elseif event == "TRADE_SHOW" or event == "TRADE_SKILL_SHOW" or
               event == "AUCTION_HOUSE_SHOW" then
            AutoShowInventory()
        end
    end)
    autoEventFrame:RegisterEvent("MAIL_CLOSED")
    autoEventFrame:RegisterEvent("TRADE_CLOSED")
    autoEventFrame:RegisterEvent("TRADE_SKILL_CLOSE")
    autoEventFrame:RegisterEvent("AUCTION_HOUSE_CLOSED")
    autoEventFrame:RegisterEvent("TRADE_SHOW")
    autoEventFrame:RegisterEvent("TRADE_SKILL_SHOW")
    autoEventFrame:RegisterEvent("AUCTION_HOUSE_SHOW")
    mod.BagsterModule.frames.autoEventFrame = autoEventFrame

    -- Slash commands
    SlashCmdList["DRAGONUI_BAGSTER"] = function(msg)
        msg = msg and msg:lower() or ""
        if msg == "bank" then
            mod:Toggle(BANK_CONTAINER)
        elseif msg == "bags" or msg == "inventory" then
            mod:Toggle(BACKPACK_CONTAINER)
        else
            mod:Toggle(BACKPACK_CONTAINER)
        end
    end
    SLASH_DRAGONUI_BAGSTER1 = "/cbt"
    SLASH_DRAGONUI_BAGSTER2 = "/bagster"
    SLASH_DRAGONUI_BAGSTER3 = "/combuctor" -- legacy alias for muscle memory

    mod.BagsterModule.applied = true
end

local function RestoreBagsterSystem()
    if not mod.BagsterModule.applied then return end

    -- Apply did BankFrame:UnregisterAllEvents(); without these the native bank never opens again
    BankFrame:RegisterEvent("BANKFRAME_OPENED")
    BankFrame:RegisterEvent("BANKFRAME_CLOSED")

    if mod.BagsterModule.originalStates.GuildBankFrame_LoadUI then
        _G.GuildBankFrame_LoadUI = mod.BagsterModule.originalStates.GuildBankFrame_LoadUI
    end
    if mod.HideGuildFrame then
        mod.HideGuildFrame()
    end

    if mod.BagsterModule.frames.autoEventFrame then
        mod.BagsterModule.frames.autoEventFrame:UnregisterAllEvents()
        mod.BagsterModule.frames.autoEventFrame:SetScript("OnEvent", nil)
    end

    -- Hide all frames
    if mod.frames then
        for _, frame in pairs(mod.frames) do
            if frame.HideFrame then frame:HideFrame() end
        end
    end
    HighlightMainMenuBags()

    -- Restore original bag functions
    if mod.BagsterModule.originalStates.OpenBackpack then
        _G.OpenBackpack = mod.BagsterModule.originalStates.OpenBackpack
    end
    if mod.BagsterModule.originalStates.ToggleBank then
        _G.ToggleBank = mod.BagsterModule.originalStates.ToggleBank
    end
    if mod.BagsterModule.originalStates.ToggleBackpack then
        _G.ToggleBackpack = mod.BagsterModule.originalStates.ToggleBackpack
    end
    if mod.BagsterModule.originalStates.OpenAllBags then
        _G.OpenAllBags = mod.BagsterModule.originalStates.OpenAllBags
    end
    if mod.BagsterModule.originalStates.ToggleAllBags then
        _G.ToggleAllBags = mod.BagsterModule.originalStates.ToggleAllBags
    end
    if mod.BagsterModule.originalStates.ToggleBag then
        _G.ToggleBag = mod.BagsterModule.originalStates.ToggleBag
    end
    if mod.BagsterModule.originalStates.ToggleKeyRing then
        _G.ToggleKeyRing = mod.BagsterModule.originalStates.ToggleKeyRing
    end

    mod.BagsterModule.originalStates = {}
    mod.BagsterModule.applied = false
end

local function RefreshBagsterFrames()
    if not mod.frames then return end

    for _, frame in pairs(mod.frames) do
        if frame and frame.UpdateSets then
            frame:UpdateSets()
        end
        if frame and frame.SetLeftSideFilter then
            frame:SetLeftSideFilter(frame:IsSideFilterOnLeft())
        end
        if frame and frame.UpdateClampInsets then
            frame:UpdateClampInsets()
        end

        -- Re-skin items (guarded per-slot via _BagSkin_Applied)
        if frame then
            local name = frame:GetName()
            local gframe = _G[name]
            if gframe then
                mod.BagsterSkinItems(gframe)
            end
        end

        if frame and frame.UpdateBottomLayout then
            frame:UpdateBottomLayout()
        end

        -- Re-apply borders and layout so glow/scale/spacing option changes show live
        if frame and frame.itemFrame then
            for _, item in pairs(frame.itemFrame.items) do
                item:UpdateBorder()
            end
            frame.itemFrame:RequestLayout()
        end

        if frame and frame.moneyFrame and frame.moneyFrame.RefreshDisplay then
            frame.moneyFrame:RefreshDisplay()
        end
    end

    -- Guild frame lives outside mod.frames
    if mod.guildFrame and mod.guildFrame.itemFrame then
        for _, item in pairs(mod.guildFrame.itemFrame.items) do
            item:UpdateBorder()
        end
        mod.guildFrame.itemFrame:RequestLayout()
        if mod.guildFrame.moneyFrame then
            mod.guildFrame.moneyFrame:RefreshDisplay()
        end
    end
end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    if mod.IsModuleEnabled() then
        if not mod.BagsterModule.applied then
            ApplyBagsterSystem()
        else
            -- Profile changed while module is active: refresh mod.DB and existing frames
            mod.SetupDatabase()
            if not mod.DB then return end

            -- Sets remain as stored in profile (empty = no category tabs)

            -- Update existing frames to point to new mod.DB tables
            if mod.frames then
                for _, frame in pairs(mod.frames) do
                    if frame.key and mod.DB[frame.key] then
                        frame.sets = mod.DB[frame.key]
                        frame:SetWidth(frame.sets.w or 384)
                        frame:SetHeight(frame.sets.h or 440)
                        if frame.UpdateSets then
                            frame:UpdateSets()
                        end
                    end
                end
            end
        end
    else
        if addon:ShouldDeferModuleDisable("bagster", mod.BagsterModule) then
            return
        end
        RestoreBagsterSystem()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("CVAR_UPDATE")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not mod.IsModuleEnabled() then return end

        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(mod, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(mod, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(mod, "OnProfileReset", OnProfileChanged)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not mod.IsModuleEnabled() then return end
        ApplyBagsterSystem()

    elseif event == "CVAR_UPDATE" and arg1 == "colorblindMode" then
        if mod.IsModuleEnabled() then
            RefreshBagsterFrames()
        end
    end
end)

-- Export for external use
addon.ApplyBagsterSystem = ApplyBagsterSystem
addon.RestoreBagsterSystem = RestoreBagsterSystem
addon.RefreshBagsterFrames = RefreshBagsterFrames
addon.BagsterItemSlot = mod.ItemSlot
addon.BagsterSyncKeyRingChecked = SyncKeyRingChecked
addon.BagsterHighlightMainMenuBags = HighlightMainMenuBags
mod.SyncKeyRingChecked = SyncKeyRingChecked
mod.HighlightMainMenuBags = HighlightMainMenuBags
mod.ScheduleHighlightMainMenuBags = ScheduleHighlightMainMenuBags
mod.HideBlizzardKeyring = HideBlizzardKeyring
