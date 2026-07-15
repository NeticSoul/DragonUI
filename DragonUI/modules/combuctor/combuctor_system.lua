-- Apply/restore lifecycle, profile-change handling, init events, slash commands, addon.* exports.
local addon = select(2, ...)
local mod = addon.CombuctorModule

-- ============================================================================
-- APPLY / RESTORE SYSTEM
-- ============================================================================

local AutoShowInventory, AutoHideInventory

local function ApplyCombuctorSystem()
    if mod.CombuctorModule.applied then return end

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
    mod.CombuctorApplySkin()

    AutoShowInventory = function()
        mod:Show(BACKPACK_CONTAINER, true)
    end
    AutoHideInventory = function()
        mod:Hide(BACKPACK_CONTAINER, true)
    end

    mod.CombuctorModule.originalStates.OpenBackpack = _G.OpenBackpack
    mod.CombuctorModule.originalStates.ToggleBank = _G.ToggleBank
    mod.CombuctorModule.originalStates.ToggleBackpack = _G.ToggleBackpack
    mod.CombuctorModule.originalStates.OpenAllBags = _G.OpenAllBags
    mod.CombuctorModule.originalStates.ToggleAllBags = _G.ToggleAllBags
    mod.CombuctorModule.originalStates.ToggleBag = _G.ToggleBag

    -- Hook bag functions
    _G.OpenBackpack = AutoShowInventory
    if not mod.CombuctorModule.hooks.closeBackpack then
        hooksecurefunc("CloseBackpack", AutoHideInventory)
        mod.CombuctorModule.hooks.closeBackpack = true
    end

    _G.ToggleBank = function(bag) mod:Toggle(bag) end
    _G.ToggleBackpack = function() mod:Toggle(BACKPACK_CONTAINER) end
    _G.ToggleBag = function(slot)
        if slot == BACKPACK_CONTAINER then
            mod:Toggle(BACKPACK_CONTAINER)
        else
            mod:Toggle(slot)
        end
    end
    -- Some keybind paths call OpenAllBags directly, so make it a true toggle.
    _G.OpenAllBags = function() mod:Toggle(BACKPACK_CONTAINER) end
    if _G.ToggleAllBags then
        _G.ToggleAllBags = function() mod:Toggle(BACKPACK_CONTAINER) end
    end

    if not mod.CombuctorModule.hooks.closeAllBags then
        hooksecurefunc("CloseAllBags", function() mod:Hide(BACKPACK_CONTAINER) end)
        mod.CombuctorModule.hooks.closeAllBags = true
    end
    BankFrame:UnregisterAllEvents()
    BankFrame:Hide()

    if not mod.CombuctorModule.hooks.inventoryEvents then
        mod("InventoryEvents"):Register(mod, "BANK_OPENED", function()
            mod:Show(BANK_CONTAINER, true)
            mod:Show(BACKPACK_CONTAINER, true)
        end)
        mod("InventoryEvents"):Register(mod, "BANK_CLOSED", function()
            mod:Hide(BANK_CONTAINER, true)
            mod:Hide(BACKPACK_CONTAINER, true)
        end)
        mod.CombuctorModule.hooks.inventoryEvents = true
    end

    -- Auto show/hide on trade/auction/mail
    local autoEventFrame = mod.CombuctorModule.frames.autoEventFrame or CreateFrame("Frame")
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
    mod.CombuctorModule.frames.autoEventFrame = autoEventFrame

    -- Slash commands
    SlashCmdList["DRAGONUI_COMBUCTOR"] = function(msg)
        msg = msg and msg:lower() or ""
        if msg == "bank" then
            mod:Toggle(BANK_CONTAINER)
        elseif msg == "bags" or msg == "inventory" then
            mod:Toggle(BACKPACK_CONTAINER)
        else
            mod:Toggle(BACKPACK_CONTAINER)
        end
    end
    SLASH_DRAGONUI_COMBUCTOR1 = "/cbt"
    SLASH_DRAGONUI_COMBUCTOR2 = "/combuctor"

    mod.CombuctorModule.applied = true
end

local function RestoreCombuctorSystem()
    if not mod.CombuctorModule.applied then return end

    -- Apply did BankFrame:UnregisterAllEvents(); without these the native bank never opens again
    BankFrame:RegisterEvent("BANKFRAME_OPENED")
    BankFrame:RegisterEvent("BANKFRAME_CLOSED")

    if mod.CombuctorModule.frames.autoEventFrame then
        mod.CombuctorModule.frames.autoEventFrame:UnregisterAllEvents()
        mod.CombuctorModule.frames.autoEventFrame:SetScript("OnEvent", nil)
    end

    -- Hide all frames
    if mod.frames then
        for _, frame in pairs(mod.frames) do
            if frame.HideFrame then frame:HideFrame() end
        end
    end

    -- Restore original bag functions
    if mod.CombuctorModule.originalStates.OpenBackpack then
        _G.OpenBackpack = mod.CombuctorModule.originalStates.OpenBackpack
    end
    if mod.CombuctorModule.originalStates.ToggleBank then
        _G.ToggleBank = mod.CombuctorModule.originalStates.ToggleBank
    end
    if mod.CombuctorModule.originalStates.ToggleBackpack then
        _G.ToggleBackpack = mod.CombuctorModule.originalStates.ToggleBackpack
    end
    if mod.CombuctorModule.originalStates.OpenAllBags then
        _G.OpenAllBags = mod.CombuctorModule.originalStates.OpenAllBags
    end
    if mod.CombuctorModule.originalStates.ToggleAllBags then
        _G.ToggleAllBags = mod.CombuctorModule.originalStates.ToggleAllBags
    end
    if mod.CombuctorModule.originalStates.ToggleBag then
        _G.ToggleBag = mod.CombuctorModule.originalStates.ToggleBag
    end

    mod.CombuctorModule.originalStates = {}
    mod.CombuctorModule.applied = false
end

local function RefreshCombuctorFrames()
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
                mod.CombuctorSkinItems(gframe)
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
end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    if mod.IsModuleEnabled() then
        if not mod.CombuctorModule.applied then
            ApplyCombuctorSystem()
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
        if addon:ShouldDeferModuleDisable("combuctor", mod.CombuctorModule) then
            return
        end
        RestoreCombuctorSystem()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not mod.IsModuleEnabled() then return end

        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(addon, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(addon, "OnProfileReset", OnProfileChanged)
            end
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not mod.IsModuleEnabled() then return end
        ApplyCombuctorSystem()
    end
end)

-- Export for external use
addon.ApplyCombuctorSystem = ApplyCombuctorSystem
addon.RestoreCombuctorSystem = RestoreCombuctorSystem
addon.RefreshCombuctorFrames = RefreshCombuctorFrames
addon.CombuctorItemSlot = mod.ItemSlot
