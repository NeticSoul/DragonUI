-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
-- DragonUI - Key Bindings search
-- A search box in the Key Bindings window's bottom bar that filters the list
-- by command name or bound key. Blizzard's list only scrolls; the bar under
-- it is a status line that most people take for a search box, so it becomes one.
-- ============================================================================

local addon = select(2, ...)

local searchBox, hint
local query = ""
local visible = {}          -- binding indices to draw, in list order
local stockUpdate           -- Blizzard's KeyBindingFrame_Update, kept for the empty query

local function Lower(text)
    return string.lower(text or "")
end

-- A row matches when every word of the query is in its command name or one of
-- its key names ("numpad", "f5", "shift"). Headers stay when a row under them matches.
local function Matches(commandName, binding1, binding2)
    local haystack = Lower(GetBindingText(commandName, "BINDING_NAME_"))
    if binding1 then haystack = haystack .. " " .. Lower(GetBindingText(binding1, "KEY_")) .. " " .. Lower(binding1) end
    if binding2 then haystack = haystack .. " " .. Lower(GetBindingText(binding2, "KEY_")) .. " " .. Lower(binding2) end
    for word in string.gmatch(query, "%S+") do
        if not string.find(haystack, word, 1, true) then return false end
    end
    return true
end

local function Collect()
    wipe(visible)
    local pendingHeader
    for index = 1, GetNumBindings() do
        local commandName, binding1, binding2 = GetBinding(index, KeyBindingFrame.mode)
        if strsub(commandName, 1, 6) == "HEADER" then
            pendingHeader = index
        elseif Matches(commandName, binding1, binding2) then
            if pendingHeader then
                visible[#visible + 1] = pendingHeader
                pendingHeader = nil
            end
            visible[#visible + 1] = index
        end
    end
end

-- Blizzard's update with the list index mapped through the filtered set. The
-- stock function is kept for the empty query so its behaviour is untouched then.
local function FilteredUpdate()
    Collect()
    local numVisible = #visible
    local offset = FauxScrollFrame_GetOffset(KeyBindingFrameScrollFrame)
    for i = 1, KEY_BINDINGS_DISPLAYED do
        local row = _G["KeyBindingFrameBinding" .. i]
        local index = visible[offset + i]
        if index then
            local button1 = _G["KeyBindingFrameBinding" .. i .. "Key1Button"]
            local button2 = _G["KeyBindingFrameBinding" .. i .. "Key2Button"]
            local description = _G["KeyBindingFrameBinding" .. i .. "Description"]
            local header = _G["KeyBindingFrameBinding" .. i .. "Header"]
            local commandName, binding1, binding2 = GetBinding(index, KeyBindingFrame.mode)
            if strsub(commandName, 1, 6) == "HEADER" then
                header:SetText(_G["BINDING_" .. commandName])
                header:Show()
                button1:Hide()
                button2:Hide()
                description:Hide()
            else
                header:Hide()
                button1:Show()
                button2:Show()
                description:Show()
                button1.commandName = commandName
                button2.commandName = commandName
                if binding1 then
                    button1:SetText(GetBindingText(binding1, "KEY_"))
                    button1:SetAlpha(1)
                else
                    button1:SetText(NORMAL_FONT_COLOR_CODE .. NOT_BOUND .. FONT_COLOR_CODE_CLOSE)
                    button1:SetAlpha(0.8)
                end
                if binding2 then
                    button2:SetText(GetBindingText(binding2, "KEY_"))
                    button2:SetAlpha(1)
                else
                    button2:SetText(NORMAL_FONT_COLOR_CODE .. NOT_BOUND .. FONT_COLOR_CODE_CLOSE)
                    button2:SetAlpha(0.8)
                end
                description:SetText(GetBindingText(commandName, "BINDING_NAME_"))
                button1:UnlockHighlight()
                button2:UnlockHighlight()
                if KeyBindingFrame.selected == commandName then
                    if KeyBindingFrame.keyID == 1 then button1:LockHighlight() else button2:LockHighlight() end
                end
            end
            row:Show()
        else
            row:Hide()
        end
    end
    FauxScrollFrame_Update(KeyBindingFrameScrollFrame, numVisible, KEY_BINDINGS_DISPLAYED, KEY_BINDING_HEIGHT)
    KeyBindingFrame_UpdateUnbindKey()
end

local function Update()
    if query and query ~= "" then
        FilteredUpdate()
    else
        stockUpdate()
    end
end

local function ScrollToTop()
    FauxScrollFrame_SetOffset(KeyBindingFrameScrollFrame, 0)
    local bar = _G["KeyBindingFrameScrollFrameScrollBar"]
    if bar then bar:SetValue(0) end
end

-- A key press while a binding is selected would bind it, so typing in the box
-- first drops the selection, the way clicking the selected button again does.
local function Deselect()
    if not KeyBindingFrame.selected then return end
    KeyBindingFrame_SetSelected(nil)
    if KeyBindingFrame.buttonPressed then KeyBindingFrame.buttonPressed:UnlockHighlight() end
    KeyBindingFrameOutputText:SetText("")
    Update()
end

local function Install()
    if searchBox or not KeyBindingFrame or not KeyBindingFrame_Update then return end
    stockUpdate = KeyBindingFrame_Update
    KeyBindingFrame_Update = Update

    -- Named because InputBoxTemplate builds its border out of $parent-prefixed regions.
    searchBox = CreateFrame("EditBox", "DragonUIKeyBindingSearchBox", KeyBindingFrame, "InputBoxTemplate")
    searchBox:SetSize(200, 20)
    searchBox:SetPoint("BOTTOMLEFT", KeyBindingFrame, "BOTTOMLEFT", 24, 42)
    searchBox:SetAutoFocus(false)
    searchBox:SetTextInsets(18, 6, 0, 0)
    searchBox:SetFrameLevel(KeyBindingFrame:GetFrameLevel() + 2)

    local glass = searchBox:CreateTexture(nil, "OVERLAY")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", searchBox, "LEFT", 2, -1.5)
    glass:SetTexture(addon._dir .. "Collections\\UI-Searchbox-Icon")

    hint = searchBox:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    hint:SetPoint("LEFT", searchBox, "LEFT", 20, 0)
    hint:SetText(SEARCH)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then hint:Show() else hint:Hide() end
        local lowered = Lower(text)
        if lowered == query then return end
        query = lowered
        ScrollToTop()
        Update()
    end)
    searchBox:SetScript("OnEditFocusGained", function() hint:Hide(); Deselect() end)
    searchBox:SetScript("OnEditFocusLost", function(self)
        if (self:GetText() or "") == "" then hint:Show() end
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- The status line shares the bar: it moves out from under the box and
    -- centres in what is left, so bind prompts and errors still show.
    KeyBindingFrameOutputText:ClearAllPoints()
    KeyBindingFrameOutputText:SetPoint("LEFT", searchBox, "RIGHT", 12, 0)
    KeyBindingFrameOutputText:SetPoint("RIGHT", KeyBindingFrame, "RIGHT", -30, 0)
    KeyBindingFrameOutputText:SetJustifyH("CENTER")

    -- Every opening starts with the whole list, as Blizzard's does.
    KeyBindingFrame:HookScript("OnHide", function()
        query = ""
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, name)
    if name == "Blizzard_BindingUI" then Install() end
end)
Install()
