-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
if not addon.TalentModule then addon.TalentModule = {} end
local L = addon.L
local T = addon.TalentModule

local LibDeflate = LibStub and LibStub("LibDeflate", true) or nil
local MAX_SAVED = 10
local FORMAT_VERSION = 1

local CLASS_IDS = {
    WARRIOR = 1, PALADIN = 2, HUNTER = 3, ROGUE = 4, PRIEST = 5,
    DEATHKNIGHT = 6, SHAMAN = 7, MAGE = 8, WARLOCK = 9, DRUID = 11,
}
local CLASS_ID_TO_FILE = {
    [1]="WARRIOR", [2]="PALADIN", [3]="HUNTER", [4]="ROGUE", [5]="PRIEST",
    [6]="DEATHKNIGHT", [7]="SHAMAN", [8]="MAGE", [9]="WARLOCK", [11]="DRUID",
}

local function buildStruct()
    if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo and UnitClass) then return nil end
    local _, classFile = UnitClass("player")
    classFile = classFile or "UNKNOWN"
    local group = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
    local s = { class = classFile, classID = CLASS_IDS[classFile], group = group, tabs = {} }
    local numTabs = GetNumTalentTabs(false, false) or 0
    for tab = 1, numTabs do
        local n = GetNumTalents(tab, false, false) or 0
        local td = { count = n, talents = {} }
        for i = 1, n do
            local _, _, _, _, rank, maxRank = GetTalentInfo(tab, i, false, false, group)
            td.talents[i] = { rank = rank or 0, maxRank = maxRank or 0 }
        end
        s.tabs[tab] = td
    end
    return s
end

local function currentRanks()
    local ranks = {}
    if not (GetNumTalentTabs and GetNumTalents and GetTalentInfo) then return ranks end
    local group = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
    for tab = 1, (GetNumTalentTabs(false, false) or 0) do
        local t = {}
        for i = 1, (GetNumTalents(tab, false, false) or 0) do
            local _, _, _, _, rank = GetTalentInfo(tab, i, false, false, group)
            t[i] = rank or 0
        end
        ranks[tab] = t
    end
    return ranks
end
T.LO_ReadCurrentRanks = currentRanks

-- ---------------------------------------------------------------------------
-- Serialise / deserialise (compressed)
-- ---------------------------------------------------------------------------
local function encodeRanks(struct)
    local bytes = {}
    bytes[#bytes + 1] = string.char(FORMAT_VERSION)
    bytes[#bytes + 1] = string.char(struct.classID or 0)
    for tab = 1, 3 do
        local td = struct.tabs[tab]
        if td then
            local count = td.count or 0
            bytes[#bytes + 1] = string.char(count)
            for i = 1, count do
                bytes[#bytes + 1] = string.char(td.talents[i] and td.talents[i].rank or 0)
            end
        end
    end
    local raw = table.concat(bytes)
    if LibDeflate then
        return LibDeflate:EncodeForPrint(LibDeflate:CompressDeflate(raw))
    end
    return raw
end

local function decodeRanks(text, expectedClassFile)
    if not text or text == "" then return nil end
    text = (text or ""):gsub("%s+", "")
    local raw
    if LibDeflate then
        raw = LibDeflate:DecompressDeflate(LibDeflate:DecodeForPrint(text))
        if not raw then raw = text end
    else
        raw = text
    end
    if #raw < 2 then return nil end
    local version = string.byte(raw, 1)
    if version ~= FORMAT_VERSION then return nil end
    local classID = string.byte(raw, 2)
    local classFile = CLASS_ID_TO_FILE[classID]
    if not classFile then return nil end
    if expectedClassFile and classFile ~= expectedClassFile then return nil, classFile end
    local ranks, idx = {}, 3
    for tab = 1, 3 do
        ranks[tab] = {}
        local count = 0
        if idx <= #raw then
            count = string.byte(raw, idx)
            idx = idx + 1
        end
        local maxTalents = 0
        for t = 1, (count or 0) do
            if idx <= #raw then
                local r = string.byte(raw, idx)
                ranks[tab][t] = r
                maxTalents = t
                idx = idx + 1
            else
                break
            end
        end
        ranks[tab].count = maxTalents
    end
    return { class = classFile, classID = classID, ranks = ranks }
end

function T.LO_EncodeCurrent()
    local struct = buildStruct()
    if not struct then return nil end
    return encodeRanks(struct), struct
end

function T.LO_Decode(text)
    local _, classFile = UnitClass("player")
    return decodeRanks(text, classFile)
end

-- ---------------------------------------------------------------------------
-- Saved-build store
-- ---------------------------------------------------------------------------
local function store()
    local cfg = addon:GetModuleConfig("talents")
    if not cfg then return nil end
    cfg.talentBuilds = cfg.talentBuilds or {}
    local _, classFile = UnitClass("player")
    classFile = classFile or "UNKNOWN"
    cfg.talentBuilds[classFile] = cfg.talentBuilds[classFile] or {}
    return cfg.talentBuilds[classFile]
end

function T.LO_List()
    local db = store(); if not db then return {} end
    local out = {}
    for name in pairs(db) do out[#out + 1] = name end
    table.sort(out)
    return out
end

function T.LO_Get(name)
    local db = store(); return db and db[name] or nil
end

function T.LO_Save(name, build)
    if not name or name == "" or not build or not build.ranks then return false end
    local db = store(); if not db then return false end
    if db[name] then return false, "A loadout with this name already exists" end
    while T.tcount and T.tcount(db) >= MAX_SAVED or select("#", pairs(db)) >= MAX_SAVED do
        local names = T.LO_List()
        if #names == 0 then break end
        db[names[1]] = nil
    end
    db[name] = { name = name, class = build.class, ranks = build.ranks }
    return true
end

function T.LO_Delete(name)
    local db = store(); if db then db[name] = nil end
    if addon and addon.db and addon.db.profile and addon.db.profile.modules then
        local cfg = addon.db.profile.modules.talents
        if cfg then
            cfg.talentBuilds = cfg.talentBuilds or {}
            local _, classFile = UnitClass("player")
            classFile = classFile or "UNKNOWN"
            cfg.talentBuilds[classFile] = cfg.talentBuilds[classFile] or {}
            cfg.talentBuilds[classFile][name] = nil
        end
    end
    return db ~= nil
end

function T.LO_Rename(oldName, newName)
    local db = store()
    if not (db and db[oldName]) or not newName or newName == "" or db[newName] then return false end
    db[newName] = db[oldName]; db[newName].name = newName; db[oldName] = nil
    return true
end

-- Apply a build: stage preview points to match the target, then the user clicks Apply.
function T.LO_ApplyBuild(name)
    local b = T.LO_Get(name); if not b then return false end
    if not (AddPreviewTalentPoints and GetTalentInfo) then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local group = T._activeGroup or (GetActiveTalentGroup and GetActiveTalentGroup()) or 1

    if T.DiscardPreview then T.DiscardPreview(group, false) end

    local conflicts = {}
    local total = 0
    for tab = 1, 3 do
        local src = b.ranks[tab] or {}
        for i, want in pairs(src) do
            local idx = tonumber(i)
            if idx then
                local _, _, _, _, live = GetTalentInfo(tab, idx, false, false, group)
                if (live or 0) > want then
                    conflicts[#conflicts + 1] = { tab = tab, idx = idx, have = live or 0, want = want }
                end
            end
        end
    end

    local staged, guardN = 0, 0
    local changed = true
    while changed and guardN < 300 do
        changed = false; guardN = guardN + 1
        for tab = 1, 3 do
            local src = b.ranks[tab] or {}
            for i, want in pairs(src) do
                local idx = tonumber(i)
                if idx then
                    local _, _, _, _, _, _, _, _, preview = GetTalentInfo(tab, idx, false, false, group)
                    preview = preview or 0
                    if preview < want then
                        pcall(AddPreviewTalentPoints, tab, idx, 1, false, group)
                        local _, _, _, _, _, _, _, _, after = GetTalentInfo(tab, idx, false, false, group)
                        if (after or 0) > preview then changed = true; staged = staged + 1 end
                    end
                end
            end
        end
        total = staged
    end
    if T.Refresh then T.Refresh() end
    return true, conflicts, staged, group
end

function T.LO_StarterBuild()
    local group = T._activeGroup or (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
    if T.DiscardPreview then T.DiscardPreview(group, false) end
    if T.Refresh then T.Refresh() end
    return true
end

-- ---------------------------------------------------------------------------
-- UI: popups, custom hyperlink, filter dropdown
-- ---------------------------------------------------------------------------
StaticPopupDialogs["DUI_TALENT_LO_SAVE"] = {
    text = (L["Name this loadout (saves your current spec):"] or "Name this loadout:"):format(),
    button1 = SAVE or "Save", button2 = CANCEL or "Cancel",
    hasEditBox = 1, maxLetters = 40, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(self)
        local name = (self.editBox or self.EditBox):GetText()
        if not name or name == "" then return end
        local code, struct = T.LO_EncodeCurrent()
        if not code then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (L["Could not capture current spec."] or "Could not capture current spec."))
            return
        end
        local ok, err = T.LO_Save(name, { class = struct.class, ranks = T.LO_ReadCurrentRanks() })
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (err or (L["Could not save."] or "Could not save.")))
        end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
}

StaticPopupDialogs["DUI_TALENT_LO_IMPORT"] = {
    text = L["Paste a talent build string (Ctrl+V):"] or "Paste a talent build string (Ctrl+V):",
    button1 = OKAY or "OK", button2 = CANCEL or "Cancel",
    hasEditBox = 1, editBoxWidth = 260, maxLetters = 600, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(self)
        local text = (self.editBox or self.EditBox):GetText()
        if not text or text == "" then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (L["Invalid build string."] or "Invalid build string.")) end
            return
        end
        local raw = text:gsub("%s+", "")
        local _, expectedClass = UnitClass("player")
        local build, wrongClass = T.LO_Decode(raw)
        if not build then
            local extracted = raw:match("([A-Za-z0-9%+%/%=]+)")
            if extracted and #extracted > 10 then
                build, wrongClass = T.LO_Decode(extracted)
            end
        end
        if not build then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: Invalid build string.") end
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff555555Debug raw length: " .. tostring(#raw) .. "|r") end
            return
        end
        if wrongClass then
            if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(("|cffff0000Loadouts|r: " .. (L["This build is for %s, not your class."] or "This build is for %s, not your class.")):format(wrongClass)) end
            return
        end
        local normalized = { class = build.class, ranks = {} }
        for tab = 1, 3 do
            normalized.ranks[tab] = {}
            local src = build.ranks and build.ranks[tab]
            if src then
                for i = 1, 10 do
                    local v = src[i]
                    if v ~= nil then normalized.ranks[tab][i] = v end
                end
            end
        end
        local defaultName = ("Imported %s"):format(date("%H:%M"))
        StaticPopupDialogs["DUI_TALENT_LO_SAVE_NAME"].text = (L["Name this imported loadout:"] or "Name this imported loadout:")
        StaticPopupDialogs["DUI_TALENT_LO_SAVE_NAME"].OnAccept = function(popup)
            local name = (popup.editBox or popup.EditBox):GetText()
            if not name or name == "" then return end
            local ok, err = T.LO_Save(name, normalized)
            if not ok then
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (err or "Could not save.")) end
            else
                if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Loadouts|r: Loadout imported.") end
            end
        end
        (StaticPopupDialogs["DUI_TALENT_LO_SAVE_NAME"].editBox or function() end)()
        StaticPopupDialogs["DUI_TALENT_LO_SAVE_NAME"].editBox = nil
        StaticPopup_Show("DUI_TALENT_LO_SAVE_NAME", nil, nil, { build = build, defaultName = defaultName })
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
}

StaticPopupDialogs["DUI_TALENT_LO_SAVE_NAME"] = {
    text = L["Name this imported loadout:"] or "Name this imported loadout:",
    button1 = SAVE or "Save", button2 = CANCEL or "Cancel",
    hasEditBox = 1, maxLetters = 40, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnShow = function(self) (self.editBox or self.EditBox):SetText(self.data and self.data.defaultName or "") end,
    OnAccept = function(self)
        local name = (self.editBox or self.EditBox):GetText()
        if not name or name == "" then return end
        local build = self.data and self.data.build
        if not build then return end
        local ok, err = T.LO_Save(name, build)
        if not ok then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (err or (L["Could not save."] or "Could not save.")))
        end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
}

StaticPopupDialogs["DUI_TALENT_LO_SETTINGS"] = {
    text = L["Selection Settings"] or "Selection Settings",
    button1 = L["Accept"] or "Accept",
    button2 = L["Delete"] or "Delete",
    button3 = CANCEL or "Cancel",
    hasEditBox = 1, maxLetters = 40, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnShow = function(self)
        local eb = self.editBox or _G[(self:GetName() or "") .. "EditBox"]
        if not eb then return end
        local name = self.data and self.data.name
        eb:SetText(name or "")
        eb:HighlightText()
        eb:SetFocus()
    end,
    OnAccept = function(self)
        local eb = self.editBox or _G[(self:GetName() or "") .. "EditBox"]
        local newName = eb and eb:GetText() or ""
        if not newName or newName == "" then
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (L["Loadout name cannot be empty."] or "Loadout name cannot be empty."))
            end
            return
        end
        local oldName = self.data and self.data.name
        if oldName and newName ~= oldName then
            local build = T.LO_Get(oldName)
            if build then
                local ok, err = T.LO_Save(newName, build)
                if ok then
                    T.LO_Delete(oldName)
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Loadouts|r: " .. (L["Loadout renamed to %s."] or "Loadout renamed to %s."):format(newName))
                    end
                else
                    if DEFAULT_CHAT_FRAME then
                        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (err or (L["Could not save."] or "Could not save.")))
                    end
                end
            end
        end
    end,
    OnCancel = function(self)
        local name = self.data and self.data.name
        if name and T.LO_Get(name) then
            local text = (L["Delete loadout '%s'? This cannot be undone."] or "Delete loadout '%s'? This cannot be undone."):format(name)
            StaticPopupDialogs["DUI_TALENT_LO_DELETE_CONFIRM"].data = { name = name }
            StaticPopup_Show("DUI_TALENT_LO_DELETE_CONFIRM", text, nil, { name = name })
        end
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent().button1:Click() end,
    EditBoxOnEscapePressed = function(editBox) editBox:GetParent():Hide() end,
}
StaticPopupDialogs["DUI_TALENT_LO_DELETE_CONFIRM"] = {
    text = "%s",
    button1 = YES or "Yes",
    button2 = NO or "No",
    timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnAccept = function(self)
        local name = self.data and self.data.name
        if name and T.LO_Get(name) then
            T.LO_Delete(name)
            if DEFAULT_CHAT_FRAME then
                DEFAULT_CHAT_FRAME:AddMessage("|cff00ff00Loadouts|r: " .. (L["Loadout deleted."] or "Loadout deleted."))
            end
        end
    end,
}
StaticPopupDialogs["DUI_TALENT_LO_SHARE"] = {
    text = L["Talent loadout export (Ctrl+C to copy):"] or "Talent loadout export (Ctrl+C to copy):",
    button1 = L["Post Link"] or "Post Link", button2 = CLOSE or "Close",
    hasEditBox = 1, editBoxWidth = 320, maxLetters = 600, timeout = 0, whileDead = 1, hideOnEscape = 1,
    OnShow = function(self)
        local code = T.LO_EncodeCurrent()
        local eb = self.editBox or self.EditBox
        if eb then
            eb:SetText(code or "")
            eb:HighlightText()
            eb:SetFocus()
            if eb.SetReadOnly then eb:SetReadOnly(true) end
        end
    end,
    OnAccept = function(self)
        local code = T.LO_EncodeCurrent()
        if not code then self:Hide(); return end
        local _, classFile = UnitClass("player")
        local specName = classFile or "Talents"
        if GetTalentTabInfo and GetActiveTalentGroup then
            local group = (GetActiveTalentGroup and GetActiveTalentGroup()) or 1
            local n = GetTalentTabInfo(1, false, false, group)
            if type(n) == "string" and n ~= "" then specName = n end
        end
        local text = "|cffFFD200|Hdui_talents:" .. code .. "|h[DUI Talents: " .. specName .. "]|h|r"
        if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
            DEFAULT_CHAT_FRAME:AddMessage(text)
        end
        self:Hide()
    end,
    EditBoxOnEnterPressed = function(self) self:GetParent():Hide() end,
    EditBoxOnEscapePressed = function(self) self:GetParent():Hide() end,
}

-- Custom hyperlink hover/click for |Hdui_talents|...|h (player-to-player)
local function duiTalentsLinkHandler(link, text, button)
    local build, wrongClass = T.LO_Decode(link)
    GameTooltip:SetOwner(WorldFrame, "ANCHOR_NONE")
    GameTooltip:ClearLines()
    if not build then
        GameTooltip:AddLine("|cffFF0000" .. (L["Invalid talent build."] or "Invalid talent build."))
        GameTooltip:Show()
        return
    end
    GameTooltip:AddLine(text and text:gsub("%[",""):gsub("%]","") or (L["DUI Talents"] or "DUI Talents"), 1, 0.84, 0.18)
    GameTooltip:AddLine(" ")
    for tab = 1, 3 do
        local src = build.ranks and build.ranks[tab]
        if src and next(src) then
            local total = 0
            for _, v in pairs(src) do total = total + v end
            GameTooltip:AddLine(("|cffFFD200Tab %d:|r %d points"):format(tab, total), 1, 1, 1)
        end
    end
    GameTooltip:Show()
end

local function duiTalentsLinkOnEnter(self, link, text)
    duiTalentsLinkHandler(link, text, "enter")
end
local function duiTalentsLinkOnLeave(self, link, text)
    GameTooltip:Hide()
end
local function duiTalentsLinkOnClick(self, link, text, button)
    local dataStr = ""
    if link and link ~= "" then dataStr = (link or ""):gsub("%s+", "") end
    if dataStr == "" then dataStr = (text or ""):gsub("%s+", "") end
    local extracted = (dataStr or ""):match("dui_talents:([^|]+)")
    if extracted then dataStr = extracted end
    local build, wrongClass = T.LO_Decode(dataStr)
    if not build then
        if DEFAULT_CHAT_FRAME then
            DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: Invalid talent build.")
        end
        return
    end
    if not build then
        DEFAULT_CHAT_FRAME:AddMessage("|cffff0000" .. (L["Invalid talent build."] or "Invalid talent build."))
        return
    end
    local _, expectedClass = UnitClass("player")
    if build.class and build.class ~= expectedClass then
        DEFAULT_CHAT_FRAME:AddMessage(("|cffff0000" .. (L["This build is for %s, not your class."] or "This build is for %s, not your class.")):format(build.class))
        return
    end
    local defaultName = ("Shared %s"):format(date("%H:%M"))
    T._loPendingShare = { name = defaultName, build = build }
    StaticPopupDialogs["DUI_TALENT_LO_SAVE_NAME"].text = (L["Save and apply this shared build:"] or "Save and apply:")
    StaticPopup_Show("DUI_TALENT_LO_SAVE_NAME", nil, nil, { build = build, defaultName = defaultName })
end

do
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("PLAYER_LOGIN")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function()
        if not addon:IsModuleEnabled("talents") then return end
        if type(SetItemRef) ~= "function" then return end
        if T.hooks["SetItemRef"] then return end

        local orig = SetItemRef
        T.hooks["SetItemRef"] = orig
        _G.DragonUI_OriginalSetItemRef = orig

        SetItemRef = function(link, text, button)
            if type(link) == "string" and link:sub(1, 11) == "dui_talents" then
                if T.applied then duiTalentsLinkOnClick(nil, link:sub(13), text, button) end
                return
            end
            return T.hooks["SetItemRef"](link, text, button)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Dropdown
-- ---------------------------------------------------------------------------
local filterButton = nil
local dropdownEntries = {}

local function buildDropdown()
    if filterButton and filterButton:IsShown() then
        if (T.IsInspecting and T.IsInspecting()) or (T._petView) or (T.GlyphsIsActive and T.GlyphsIsActive()) then
            filterButton:Hide()
        end
    end
    if filterButton then return filterButton end
    local f = T.frame
    if not f then return nil end
    filterButton = CreateFrame("Button", "DragonUI_TalentLoadoutsFilter", f, "UIPanelButtonTemplate")
    filterButton:SetSize(92, 22)
    filterButton:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", (T.FRAME.CHROME_L or 0) + 24, (T.FRAME.CHROME_B or 0) + 30)
    filterButton:SetText(L["Loadouts"] or "Loadouts")
    for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }) do
        local tex = filterButton[getter] and filterButton[getter](filterButton)
        if tex then tex:SetTexture(nil) end
    end
    local holder = filterButton:CreateTexture(nil, "BACKGROUND")
    local info = addon.atlasinfo and addon.atlasinfo["common-dropdown-b-button"]
    if info then
        holder:SetTexture(info[1])
        holder:SetTexCoord(info[4], info[5], info[6], info[7])
    else
        holder:SetTexture("Interface\\Buttons\\UI-OptionsButton")
    end
    holder:SetPoint("TOPLEFT", filterButton, "TOPLEFT", -2, 2)
    holder:SetPoint("BOTTOMRIGHT", filterButton, "BOTTOMRIGHT", 2, -2)
    filterButton:SetScript("OnClick", function(self)
        dropdownEntries = {}
        local builds = T.LO_List()
        dropdownEntries[#dropdownEntries + 1] = {
            text = " ",
            isTitle = true,
        }
        for _, name in ipairs(builds) do
            local info = T.LO_Get(name)
            local classText = info and info.class or ""
            dropdownEntries[#dropdownEntries + 1] = {
                text = "|cffffd100" .. classText .. " — " .. name .. "|r",
                func = function()
                    if not T.LO_ApplyBuild then return end
                    local ok, conflicts, staged, group = T.LO_ApplyBuild(name)
                    if not ok then
                        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (L["Cannot apply loadout right now."] or "Cannot apply loadout right now.")) end
                        return
                    end
                    local nConflicts = #(conflicts or {})
                    if staged and staged > 0 then
                        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(("|cff00ff00Loadouts|r: " .. (L["%d points staged on talent group %d. Click \"Apply Changes\" to commit."] or "%d points staged on talent group %d. Click \"Apply Changes\" to commit.")):format(staged, group or 1)) end
                    elseif nConflicts > 0 then
                        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage(("|cffFFD200Loadouts|r: " .. (L["%d points conflict with this spec (need a respec); %d staged."] or "%d points conflict with this spec (need a respec); %d staged.")):format(nConflicts, staged or 0)) end
                    else
                        if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cffff0000Loadouts|r: " .. (L["0 points staged. No unspent points, or this spec is already set."] or "0 points staged. No unspent points, or this spec is already set.")) end
                    end
                end,
                funcRight = function()
                    StaticPopupDialogs["DUI_TALENT_LO_SETTINGS"].data = { name = name }
                    StaticPopup_Show("DUI_TALENT_LO_SETTINGS", nil, nil, { name = name })
                end,
                tooltip = {
                    L["Click: Apply build"] or "Click: Apply build",
                    L["Right-click: Rename / Delete"] or "Right-click: Rename / Delete",
                },
            }
        end
        dropdownEntries[#dropdownEntries + 1] = {
            text = "|cff66ccff" .. (L["Starter Build"] or "Starter Build") .. "|r",
            func = function() T.LO_StarterBuild() end,
        }
        dropdownEntries[#dropdownEntries + 1] = {
            text = "|cff00ff00" .. (L["New Loadout"] or "New Loadout") .. "|r",
            func = function() StaticPopup_Show("DUI_TALENT_LO_SAVE") end,
        }
        dropdownEntries[#dropdownEntries + 1] = {
            text = L["Import"] or "Import",
            func = function() StaticPopup_Show("DUI_TALENT_LO_IMPORT") end,
        }
        dropdownEntries[#dropdownEntries + 1] = {
            text = L["Share"] or "Share",
            func = function() StaticPopup_Show("DUI_TALENT_LO_SHARE") end,
        }
        addon.Menu.Open(self, dropdownEntries)
        PlaySound("igMainMenuOptionCheckBoxOn")
    end)
    return filterButton
end

function T.LO_TogglePanel()
    buildDropdown()
end
