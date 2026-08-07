--[[
================================================================================
DragonUI Options Panel - General Tab
================================================================================
Editor Mode, KeyBind Mode, and general settings.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local AceGUI = LibStub("AceGUI-3.0")
local C = addon.PanelControls
local Panel = addon.OptionsPanel
local LO = addon.LO

-- ============================================================================
-- PRESET SYSTEM HELPERS
-- ============================================================================

-- Keys to exclude from preset snapshots (they are meta / self-referencing)
local EXCLUDED_KEYS = { presets = true, version = true }

local Serializer = {}
LibStub("AceSerializer-3.0"):Embed(Serializer)
local LibDeflate = LibStub("LibDeflate")

-- ============================================================================
-- EXPORT / IMPORT HELPERS
-- ============================================================================

local EXPORT_HEADER = "!DUI1!"

local function ExportPresetToString(presetEntry)
    local serialized = Serializer:Serialize(presetEntry.data)
    if not serialized then return nil end
    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then return nil end
    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then return nil end
    return EXPORT_HEADER .. encoded
end

local function ImportPresetFromString(str)
    if type(str) ~= "string" then return nil, "empty" end
    str = strtrim(str)
    if str == "" then return nil, "empty" end
    if str:sub(1, #EXPORT_HEADER) ~= EXPORT_HEADER then return nil, "header" end
    local payload = str:sub(#EXPORT_HEADER + 1)
    if payload == "" then return nil, "payload" end
    local decoded = LibDeflate:DecodeForPrint(payload)
    if not decoded then return nil, "decode" end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return nil, "decompress" end
    local ok, data = Serializer:Deserialize(decompressed)
    if not ok or type(data) ~= "table" then return nil, "deserialize" end
    return data
end

-- ============================================================================
-- IMPORT / EXPORT POPUP FRAME  (shared, reusable)
-- ============================================================================

local importExportFrame

local function GetImportExportFrame()
    if importExportFrame then return importExportFrame end

    local f = CreateFrame("Frame", "DragonUI_ImportExportFrame", UIParent)
    f:SetSize(500, 350)
    f:SetPoint("CENTER")
    f:SetFrameStrata("FULLSCREEN_DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 11, top = 12, bottom = 10 },
    })
    f:Hide()
    tinsert(UISpecialFrames, "DragonUI_ImportExportFrame")

    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOP", 0, -16)

    -- Scrollframe + EditBox
    local sf = CreateFrame("ScrollFrame", "DragonUI_IEScrollFrame", f, "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 20, -45)
    sf:SetPoint("BOTTOMRIGHT", -40, 50)

    local eb = CreateFrame("EditBox", "DragonUI_IEEditBox", sf)
    eb:SetMultiLine(true)
    eb:SetAutoFocus(false)
    eb:SetFontObject(ChatFontNormal)
    eb:SetWidth(sf:GetWidth() or 430)
    eb:SetScript("OnEscapePressed", function(self) self:ClearFocus(); f:Hide() end)
    sf:SetScrollChild(eb)
    f.editBox = eb
    f.scrollFrame = sf

    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    -- Bottom button row
    f.btn1 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.btn1:SetSize(120, 24)
    f.btn1:SetPoint("BOTTOMLEFT", 20, 16)

    f.btn2 = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    f.btn2:SetSize(120, 24)
    f.btn2:SetPoint("BOTTOMRIGHT", -20, 16)
    f.btn2:SetText(LO["Cancel"] or "Cancel")
    f.btn2:SetScript("OnClick", function() f:Hide() end)

    importExportFrame = f
    return f
end

local function ShowExportFrame(presetName, exportString)
    local f = GetImportExportFrame()
    f.title:SetText(LO["Export Preset"] or "Export Preset")
    f.editBox:SetText(exportString)
    f.editBox:SetScript("OnTextChanged", function(self)
        self:SetText(exportString)  -- prevent editing
    end)
    f.editBox:SetCursorPosition(0)
    f.btn1:SetText(LO["Select All"] or "Select All")
    f.btn1:SetScript("OnClick", function()
        f.editBox:SetFocus()
        f.editBox:HighlightText()
    end)
    f.btn2:SetText(LO["Close"] or "Close")
    f.btn2:SetScript("OnClick", function() f:Hide() end)
    f:Show()
    f.editBox:SetFocus()
    f.editBox:HighlightText()
end

local function ShowImportFrame()
    local f = GetImportExportFrame()
    f.title:SetText(LO["Import Preset"] or "Import Preset")
    f.editBox:SetText("")
    f.editBox:SetScript("OnTextChanged", nil)  -- allow editing
    f.btn1:SetText(LO["Import"] or "Import")
    f.btn1:SetScript("OnClick", function()
        local text = strtrim(f.editBox:GetText())
        if text == "" then return end
        local data, errType = ImportPresetFromString(text)
        if not data then
            local msg = LO["Invalid preset string."] or "Invalid preset string."
            if errType == "header" then
                msg = LO["Not a valid DragonUI preset string."] or "Not a valid DragonUI preset string."
            end
            print("|cFFFF4444[DragonUI]|r " .. msg)
            return
        end
        f:Hide()
        -- Ask for a name
        local dialog = StaticPopup_Show("DRAGONUI_PRESET_IMPORT_NAME")
        if dialog then
            dialog.data = data
        end
    end)
    f.btn2:SetText(LO["Cancel"] or "Cancel")
    f.btn2:SetScript("OnClick", function() f:Hide() end)
    f:Show()
    f.editBox:SetFocus()
end

-- Create a clean deep copy excluding certain top-level keys
local function SnapshotProfile()
    local snapshot = {}
    for key, value in pairs(addon.db.profile) do
        if not EXCLUDED_KEYS[key] then
            if type(value) == "table" then
                snapshot[key] = addon.DeepCopy(value)
            else
                snapshot[key] = value
            end
        end
    end
    return snapshot
end

-- Restore a snapshot into the current profile (preserves presets + version)
local function RestoreSnapshot(snapshot)
    if not snapshot then return end
    for key, value in pairs(snapshot) do
        if not EXCLUDED_KEYS[key] then
            if type(value) == "table" then
                addon.db.profile[key] = addon.DeepCopy(value)
            else
                addon.db.profile[key] = value
            end
        end
    end
end

-- Get the presets table, creating it if needed
local function GetPresets()
    if not addon.db or not addon.db.profile then return {} end
    if not addon.db.profile.presets then
        addon.db.profile.presets = {}
    end
    return addon.db.profile.presets
end

-- Generate a unique preset name to avoid collisions
local function UniquePresetName(baseName)
    local presets = GetPresets()
    if not presets[baseName] then return baseName end
    local i = 2
    while presets[baseName .. " (" .. i .. ")"] do
        i = i + 1
    end
    return baseName .. " (" .. i .. ")"
end

-- ============================================================================
-- STATIC POPUP: NAME INPUT
-- ============================================================================

StaticPopupDialogs["DRAGONUI_PRESET_NAME"] = {
    text = LO["Enter a name for this preset:"],
    button1 = LO["Save"],
    button2 = LO["Cancel"],
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        if eb then
            eb:SetText(self.data or (LO["Preset"] .. " 1"))
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    OnAccept = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        local name = eb and eb:GetText() and strtrim(eb:GetText())
        if not name or name == "" then return end
        -- Sanitize: remove pipe characters to prevent color code injection
        name = name:gsub("|", "")
        if name == "" then return end
        local presets = GetPresets()
        presets[name] = {
            data = SnapshotProfile(),
            date = date("%Y-%m-%d %H:%M"),
        }
        addon:Print((LO["Preset saved: "] or "Preset saved: ") .. name)
        -- Refresh the General tab to show the new preset
        if Panel.currentTab == "general" then
            Panel:SelectTab("general")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["DRAGONUI_PRESET_NAME"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

StaticPopupDialogs["DRAGONUI_PRESET_LOAD"] = {
    text = LO["Load preset '%s'? This will overwrite your current layout settings."],
    button1 = LO["Load"],
    button2 = LO["Cancel"],
    OnAccept = function(self)
        local name = self.data
        local presets = GetPresets()
        if presets[name] and presets[name].data then
            RestoreSnapshot(presets[name].data)
            addon:Print((LO["Preset loaded: "] or "Preset loaded: ") .. name)
            ReloadUI()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

StaticPopupDialogs["DRAGONUI_PRESET_DELETE"] = {
    text = LO["Delete preset '%s'? This cannot be undone."],
    button1 = LO["Delete"],
    button2 = LO["Cancel"],
    OnAccept = function(self)
        local name = self.data
        local presets = GetPresets()
        if presets[name] then
            presets[name] = nil
            addon:Print((LO["Preset deleted: "] or "Preset deleted: ") .. name)
            if Panel.currentTab == "general" then
                Panel:SelectTab("general")
            end
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- ============================================================================
-- STATIC POPUP: IMPORT NAME INPUT
-- ============================================================================

StaticPopupDialogs["DRAGONUI_PRESET_IMPORT_NAME"] = {
    text = LO["Enter a name for the imported preset:"],
    button1 = LO["Save"],
    button2 = LO["Cancel"],
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        if eb then
            eb:SetText(UniquePresetName(LO["Imported Preset"] or "Imported Preset"))
            eb:HighlightText()
            eb:SetFocus()
        end
    end,
    OnAccept = function(self)
        local eb = self.editBox or _G[self:GetName() .. "EditBox"]
        local name = eb and eb:GetText() and strtrim(eb:GetText())
        if not name or name == "" then return end
        name = name:gsub("|", "")
        if name == "" then return end
        local importedData = self.data
        if not importedData or type(importedData) ~= "table" then return end
        local presets = GetPresets()
        presets[name] = {
            data = addon.DeepCopy(importedData),
            date = date("%Y-%m-%d %H:%M"),
        }
        addon:Print((LO["Preset imported: "] or "Preset imported: ") .. name)
        if Panel.currentTab == "general" then
            Panel:SelectTab("general")
        end
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["DRAGONUI_PRESET_IMPORT_NAME"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- ============================================================================
-- GENERAL TAB BUILDER
-- ============================================================================

local function BuildGeneralTab(scroll)
    -- ====================================================================
    -- ABOUT
    -- ====================================================================
    local about = C:AddSection(scroll, LO["About"])

    C:AddLabel(about, "|cff1784d1" .. LO["DragonUI"] .. " v2.5|r")
    C:AddDescription(about, LO["Bringing the retail WoW look to 3.3.5a, inspired by Dragonflight UI."])
    C:AddSpacer(about)
    C:AddDescription(about, LO["Created and maintained by Neticsoul, with community contributions."])
    C:AddSpacer(about)
    C:AddDescription(about, LO["Use the tabs on the left to configure modules, action bars, unit frames, minimap, and more."])
    C:AddSpacer(about)
    C:AddDescription(about, LO["Commands: /dragonui, /dui, /pi — /dragonui edit (editor) — /dragonui help"])
    C:AddSpacer(about)
    C:AddDescription(about, LO["GitHub (select and Ctrl+C to copy):"])
    C:AddCopyableText(about, "https://github.com/NeticSoul/DragonUI")

    C:AddSpacer(scroll)

    -- ====================================================================
    -- LANGUAGE
    -- ====================================================================
    local language = C:AddSection(scroll, LO["Language"])

    C:AddDescription(language, LO["Choose the language used by the DragonUI interface."])

    local localeNames = {
        enUS = "English",
        esES = "Español",
        esMX = "Español (México)",
        ptBR = "Português",
        deDE = "Deutsch",
        frFR = "Français",
        ruRU = "Русский",
        zhCN = "简体中文",
        zhTW = "繁體中文",
        koKR = "한국어",
    }

    -- Hide languages the client font cannot draw; their names would already show as "?" here.
    local localeValues = { auto = LO["Follow the client language"] }
    for code, name in pairs(localeNames) do
        if not addon.CanRenderLocale or addon.CanRenderLocale(code) then
            localeValues[code] = name
        end
    end

    C:AddDropdown(language, {
        label = LO["Language"],
        desc  = LO["Choose the language used by the DragonUI interface."],
        values = localeValues,
        getFunc = function()
            return (addon.db and addon.db.global and addon.db.global.locale) or "auto"
        end,
        setFunc = function(value)
            if addon.db and addon.db.global then
                addon.db.global.locale = value
            end
        end,
        callback = function()
            StaticPopup_Show("DRAGONUI_RELOAD_UI")
        end,
        width = 200,
    })

    C:AddSpacer(scroll)

    -- ====================================================================
    -- QUICK ACCESS
    -- ====================================================================
    local actions = C:AddSection(scroll, LO["Quick Actions"])

    C:AddDescription(actions, LO["Jump to popular settings sections."])

    C:AddButton(actions, {
        label = LO["Dark Mode"],
        desc = LO["Configure dark tinting for all UI chrome."],
        width = 200,
        callback = function() Panel:SelectTab("enhancements") end,
    })

    C:AddButton(actions, {
        label = LO["Fat Health Bar"],
        desc = LO["Full-width health bar that fills the entire player frame."],
        width = 200,
        callback = function() Panel:SelectTab("unitframes") end,
    })

    C:AddButton(actions, {
        label = LO["Dragon Decoration"],
        desc = LO["Add a decorative dragon to your player frame."],
        width = 200,
        callback = function() Panel:SelectTab("unitframes") end,
    })

    C:AddButton(actions, {
        label = LO["Unit Frame Layers"],
        desc = LO["Heal prediction, absorb shields and animated health loss."],
        width = 200,
        callback = function() Panel:SelectTab("enhancements") end,
    })

    C:AddButton(actions, {
        label = LO["Action Bar Layout"],
        desc = LO["Change columns, rows, and buttons shown per action bar."],
        width = 200,
        callback = function()
            if addon.SetActionBarSubTab then addon.SetActionBarSubTab("layout") end
            Panel:SelectTab("actionbars")
        end,
    })

    C:AddButton(actions, {
        label = LO["Grayscale Icons"],
        desc = LO["Switch micro menu icons between colored and grayscale style."],
        width = 200,
        callback = function() Panel:SelectTab("micromenu") end,
    })

    C:AddSpacer(scroll)

    -- ====================================================================
    -- LAYOUT PRESETS
    -- ====================================================================
    local presets = C:AddSection(scroll, LO["Layout Presets"])

    C:AddDescription(presets, LO["Save and restore complete UI layouts. Each preset captures all positions, scales, and settings."])

    C:AddSpacer(presets)

    -- Collect sorted preset names
    local presetData = GetPresets()
    local presetNames = {}
    for name in pairs(presetData) do
        presetNames[#presetNames + 1] = name
    end
    table.sort(presetNames)

    if #presetNames == 0 then
        C:AddLabel(presets, "|cff888888" .. LO["No presets saved yet."] .. "|r")
        C:AddSpacer(presets)
    else
        -- Preset list: clickable labels that trigger load on click
        for _, name in ipairs(presetNames) do
            local entry = presetData[name]
            local dateStr = entry.date or ""

            local row = AceGUI:Create("SimpleGroup")
            row:SetFullWidth(true)
            row:SetLayout("Flow")
            presets:AddChild(row)

            local btn = AceGUI:Create("InteractiveLabel")
            btn:SetWidth(350)
            btn:SetText("  |cffFFFFFF" .. name .. "|r  |cff666666" .. dateStr .. "|r")
            if btn.label then
                btn.label:SetFont(C.Theme.font, 12, "")
            end

            -- Hover highlight frame (visual feedback only)
            local hlFrame = CreateFrame("Frame", nil, btn.frame)
            hlFrame:SetAllPoints(btn.frame)
            hlFrame:SetFrameLevel(btn.frame:GetFrameLevel())
            local hlTex = hlFrame:CreateTexture(nil, "BACKGROUND")
            hlTex:SetAllPoints()
            hlTex:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
            hlTex:SetVertexColor(0.09, 0.52, 0.82, 0)

            btn:SetCallback("OnClick", function()
                local dialog = StaticPopup_Show("DRAGONUI_PRESET_LOAD", name)
                if dialog then dialog.data = name end
            end)
            btn:SetCallback("OnEnter", function()
                hlTex:SetVertexColor(0.09, 0.52, 0.82, 0.15)
            end)
            btn:SetCallback("OnLeave", function()
                hlTex:SetVertexColor(0.09, 0.52, 0.82, 0)
            end)

            row:AddChild(btn)
        end

        C:AddSpacer(presets)
    end

    -- Action buttons row
    local btnRow = C:AddRow(presets)

    -- SAVE NEW
    C:AddButton(btnRow, {
        label = LO["Save New Preset"],
        width = 140,
        desc = LO["Save your current UI layout as a new preset."],
        callback = function()
            local defaultName = UniquePresetName(LO["Preset"] or "Preset")
            local dialog = StaticPopup_Show("DRAGONUI_PRESET_NAME")
            if dialog then dialog.data = defaultName end
        end,
    })

    -- LOAD (enabled only when a preset can be selected)
    if #presetNames > 0 then
        -- Build dropdown values
        local ddValues = {}
        for _, name in ipairs(presetNames) do
            ddValues[name] = name
        end

        C:AddDropdown(btnRow, {
            label = LO["Load Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value then
                    local dialog = StaticPopup_Show("DRAGONUI_PRESET_LOAD", value)
                    if dialog then dialog.data = value end
                end
            end,
        })

        C:AddDropdown(btnRow, {
            label = LO["Delete Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value then
                    local dialog = StaticPopup_Show("DRAGONUI_PRESET_DELETE", value)
                    if dialog then dialog.data = value end
                end
            end,
        })

        C:AddDropdown(btnRow, {
            label = LO["Duplicate Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value and presetData[value] then
                    local newName = UniquePresetName(value)
                    presetData[newName] = {
                        data = addon.DeepCopy(presetData[value].data),
                        date = date("%Y-%m-%d %H:%M"),
                    }
                    addon:Print((LO["Preset duplicated: "] or "Preset duplicated: ") .. newName)
                    Panel:SelectTab("general")
                end
            end,
        })

        C:AddDropdown(btnRow, {
            label = LO["Export Preset"],
            values = ddValues,
            width = 180,
            setFunc = function(value)
                if value and presetData[value] then
                    local exportStr = ExportPresetToString(presetData[value])
                    if exportStr then
                        ShowExportFrame(value, exportStr)
                    else
                        print("|cFFFF4444[DragonUI]|r " .. (LO["Failed to export preset."] or "Failed to export preset."))
                    end
                end
            end,
        })
    end

    -- Import button (always available, even with no presets)
    C:AddButton(btnRow, {
        label = LO["Import Preset"],
        width = 140,
        desc = LO["Import a preset from a text string shared by another player."],
        callback = function()
            ShowImportFrame()
        end,
    })
end

-- Register the tab
Panel:RegisterTab("general", LO["General"], BuildGeneralTab, 1)
