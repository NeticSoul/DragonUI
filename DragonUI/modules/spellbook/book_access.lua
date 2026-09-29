-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local Book = addon.SpellbookModule

local ipairs = ipairs

local MULTIBARS = { "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft" }

local keyOwner, lastKeys, catcher
local gridsUp = false

local function enabled()
    return addon:IsModuleEnabled("spellbook")
end

-- Key bindings ------------------------------------------------------------------------------------

local function bindKeys()
    local bookKeys = { GetBindingKey("TOGGLESPELLBOOK") }
    local petKeys = { GetBindingKey("TOGGLEPETBOOK") }
    local signature = table.concat(bookKeys, " ") .. "/" .. table.concat(petKeys, " ")
    if not enabled() then signature = "" end
    if signature == lastKeys then return end
    lastKeys = signature
    ClearOverrideBindings(keyOwner)
    if signature == "" then return end
    for _, key in ipairs(bookKeys) do
        SetOverrideBindingClick(keyOwner, false, key, "DragonUI_SpellbookToggle", "LeftButton")
    end
    for _, key in ipairs(petKeys) do
        SetOverrideBindingClick(keyOwner, false, key, "DragonUI_SpellbookToggle", "RightButton")
    end
end

function Book.QueueBindings()
    addon:SafeExecute("spellbook", "bindings", bindKeys)
end

-- Micro button catcher ----------------------------------------------------------------------------

-- Never anchored to the micro button: that would make the button and its bar protected.
function Book.PlaceMicroCatcher()
    if not catcher or Book.Locked() then return end
    -- The vehicle bar owns the micro buttons for now; its state snippet already hid the catcher.
    if SecureCmdOptionParse("[vehicleui] hide; show") == "hide" then return end
    local button = SpellbookMicroButton
    local left, bottom, width, height = button:GetRect()
    if not (enabled() and left and button:IsVisible()) then
        catcher:Hide()
        return
    end
    local ratio = button:GetEffectiveScale() / UIParent:GetEffectiveScale()
    catcher:ClearAllPoints()
    catcher:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", left * ratio, bottom * ratio)
    catcher:SetSize(width * ratio, height * ratio)
    catcher:SetFrameStrata(button:GetFrameStrata())
    catcher:SetFrameLevel(button:GetFrameLevel() + 5)
    catcher:Show()
end

-- A stale catcher corrects itself before its first click, when the pointer reaches it.
local function microEnter(self)
    Book.PlaceMicroCatcher()
    if not self:IsShown() or not self:IsMouseOver() then return end
    local text = MicroButtonTooltipText(SPELLBOOK_ABILITIES_BUTTON, "TOGGLESPELLBOOK")
    GameTooltip_AddNewbieTip(self, text, 1.0, 1.0, 1.0, NEWBIE_TOOLTIP_SPELLBOOK)
    SpellbookMicroButton:LockHighlight()
end

local function microLeave()
    SpellbookMicroButton:UnlockHighlight()
    GameTooltip_Hide()
end

local function vehicleChanged(unit)
    if unit == "player" then Book.PlaceMicroCatcher() end
end

local function buildMicroCatcher()
    catcher = CreateFrame("Button", "DragonUI_SpellbookMicroCatcher", UIParent,
        "SecureHandlerClickTemplate,SecureHandlerStateTemplate")
    catcher:Hide()
    catcher:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    SecureHandlerSetFrameRef(catcher, "root", Book.root)
    catcher:SetAttribute("_onclick", Book.SNIPPET.micro)
    catcher:SetAttribute("_onstate-vehicle", Book.SNIPPET.vehicle)
    catcher.SpellbookSync = Book.SyncLoud
    catcher:SetScript("OnEnter", microEnter)
    catcher:SetScript("OnLeave", microLeave)
    RegisterStateDriver(catcher, "vehicle", "[vehicleui] hide; show")

    -- Reaching the real button means the catcher is not over it, so it is moved there.
    local button = SpellbookMicroButton
    button:HookScript("OnEnter", Book.PlaceMicroCatcher)
    button:HookScript("OnShow", Book.PlaceMicroCatcher)
    button:HookScript("OnHide", Book.PlaceMicroCatcher)
    Book.On("PLAYER_ENTERING_WORLD", Book.PlaceMicroCatcher)
    Book.On("UNIT_ENTERED_VEHICLE", vehicleChanged)
    Book.On("UNIT_EXITED_VEHICLE", vehicleChanged)
    Book.PlaceMicroCatcher()
end

-- Blizzard's own book -----------------------------------------------------------------------------

-- In combat Blizzard's book stays usable as is; the swap waits for the end of combat.
function Book.ReclaimBlizzardBook()
    if not enabled() or Book.Locked() or not SpellBookFrame:IsShown() then return end
    local pet = SpellBookFrame.bookType == BOOKTYPE_PET
    HideUIPanel(SpellBookFrame)
    Book.OpenBook(pet)
end

-- Hiding it inside its own ShowUIPanel would re-enter the panel manager, so wait a frame.
local function blizzardBookShown()
    if enabled() then addon:After(0, Book.ReclaimBlizzardBook) end
end

-- Empty action slots ------------------------------------------------------------------------------

-- The grid calls count showgrid only for secure callers, so the book adds its own share.
local function shareGrid(delta)
    for _, bar in ipairs(MULTIBARS) do
        for slot = 1, NUM_MULTIBAR_BUTTONS do
            local button = _G[bar .. "Button" .. slot]
            local count = (button:GetAttribute("showgrid") or 0) + delta
            if count >= 0 then button:SetAttribute("showgrid", count) end
        end
    end
end

function Book.ShowActionGrids()
    if gridsUp or Book.Locked() then return end
    gridsUp = true
    shareGrid(1)
    MultiActionBar_ShowAllGrids()
end

local function lowerGrids()
    if not gridsUp or Book.IsOpen() then return end
    gridsUp = false
    shareGrid(-1)
    MultiActionBar_HideAllGrids()
end

-- Showgrid and Hide on the action buttons are protected, so a close in combat waits.
function Book.HideActionGrids()
    if not Book.Locked() then return lowerGrids() end
    addon.CombatQueue:Add("spellbook_grids", lowerGrids)
end

-- Click-casting addon's side tab ------------------------------------------------------------------

function Book.AdoptSideTab()
    local borrowed = IsAddOnLoaded("Clique") and _G.CliqueSpellTab
    if not borrowed then return end
    borrowed:SetParent(Book.root)
    borrowed:ClearAllPoints()
    borrowed:SetPoint("TOPLEFT", Book.root, "TOPRIGHT", 4, -65)
    borrowed:SetFrameLevel(Book.Level("catcher"))
    borrowed:Show()
end

-- Installation ------------------------------------------------------------------------------------

function Book.InstallAccess()
    keyOwner = CreateFrame("Frame")
    local keyButton = CreateFrame("Button", "DragonUI_SpellbookToggle", UIParent, "SecureHandlerClickTemplate")
    keyButton:Hide()
    keyButton:RegisterForClicks("AnyUp")
    SecureHandlerSetFrameRef(keyButton, "root", Book.root)
    keyButton:SetAttribute("_onclick", Book.SNIPPET.keys)
    keyButton.SpellbookSync = Book.SyncLoud
    bindKeys()

    buildMicroCatcher()

    SpellBookFrame:HookScript("OnShow", blizzardBookShown)
    hooksecurefunc("CloseAllWindows", function()
        if enabled() then Book.CloseBook() end
    end)
    hooksecurefunc("UpdateMicroButtons", function()
        Book.PlaceMicroCatcher()
        if enabled() and Book.IsOpen() then SpellbookMicroButton:SetButtonState("PUSHED", 1) end
    end)
    -- The error frame shares HIGH with this toplevel window, which rises above it when shown.
    hooksecurefunc(UIErrorsFrame, "AddMessage", function(messages)
        if Book.IsOpen() then messages:Raise() end
    end)
end
