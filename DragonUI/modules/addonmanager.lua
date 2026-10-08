-- addonmanager.lua
local AddonName = ...
local DUI = _G.DragonUI

local function T(key)
    if DUI and DUI.L and DUI.L[key] then return DUI.L[key] end
    return key
end

local character = UnitName("player")
local MAX_ADDONS_DISPLAYED = 15
local ADDON_BUTTON_HEIGHT = 22

local filteredAddons = {}
local collapsedAddons = {}
local searchText = ""
local AddonListFrame

-- Build hierarchical addon list
local function BuildFilter()
    wipe(filteredAddons)
    local numAddons = GetNumAddOns()
    local query = searchText:lower()
    
    local parents = {}
    local childrenMap = {}
    
    local function GetUltimateParent(idx)
        local visited = {}
        local current = idx
        while current do
            if visited[current] then break end
            visited[current] = true
            
            local dep1 = GetAddOnDependencies(current)
            if not dep1 then break end
            
            local found = nil
            for j = 1, numAddons do
                local n = GetAddOnInfo(j)
                if n and n:lower() == dep1:lower() then
                    found = j
                    break
                end
            end
            if found then current = found else break end
        end
        return current
    end
    
    for i = 1, numAddons do
        local root = GetUltimateParent(i)
        if root == i then
            table.insert(parents, i)
        else
            childrenMap[root] = childrenMap[root] or {}
            table.insert(childrenMap[root], i)
        end
    end
    
    for _, pIndex in ipairs(parents) do
        local pName, pTitle = GetAddOnInfo(pIndex)
        local pMatch = (query == "" or (pName and pName:lower():find(query)) or (pTitle and pTitle:lower():find(query)))
        local myChildren = childrenMap[pIndex]
        local hasMatchingChild = false
        
        if not pMatch and myChildren then
            for _, cIndex in ipairs(myChildren) do
                local cName, cTitle = GetAddOnInfo(cIndex)
                if (cName and cName:lower():find(query)) or (cTitle and cTitle:lower():find(query)) then
                    hasMatchingChild = true
                    break
                end
            end
        end
        
        if pMatch or hasMatchingChild then
            table.insert(filteredAddons, { type = "parent", index = pIndex, hasChildren = (myChildren ~= nil) })
            
            if myChildren and not collapsedAddons[pName] then
                for _, cIndex in ipairs(myChildren) do
                    local cName, cTitle = GetAddOnInfo(cIndex)
                    if query == "" or pMatch or (cName and cName:lower():find(query)) or (cTitle and cTitle:lower():find(query)) then
                        table.insert(filteredAddons, { type = "child", index = cIndex, parentIndex = pIndex })
                    end
                end
            end
        end
    end
end

local function BuildWindow()
    local FUI = DUI and DUI.ForeverUI
    if not FUI then return end

    AddonListFrame = FUI.CreateWindow("DragonUI_AddonList", UIParent, {
        width    = 620,
        height   = 479,
        title    = T("Addon Manager"),
        strata   = "DIALOG",
        movable  = true,
        escClose = true,
        closable = true,
        inset    = false,
    })
    AddonListFrame:SetPoint("CENTER")
    AddonListFrame:Hide()

    -- HEADER
    local cbOutOfDate = CreateFrame("CheckButton", "DragonUI_AddonList_OutOfDate", AddonListFrame, "UICheckButtonTemplate")
    cbOutOfDate:SetSize(24, 24)
    cbOutOfDate:SetPoint("TOPLEFT", AddonListFrame, "TOPLEFT", 14, -33)
    cbOutOfDate.text = cbOutOfDate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbOutOfDate.text:SetPoint("LEFT", cbOutOfDate, "RIGHT", 4, 0)
    cbOutOfDate.text:SetText(T("Load out of date AddOns"))
    cbOutOfDate:SetChecked(GetCVar("checkAddonVersion") == "0")
    cbOutOfDate:SetScript("OnClick", function(self)
        SetCVar("checkAddonVersion", self:GetChecked() and "0" or "1")
    end)

    local searchBox = FUI.CreateSearchBox(AddonListFrame, 160, T("Search..."))
    searchBox:SetPoint("TOPRIGHT", AddonListFrame, "TOPRIGHT", -16, -35)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText()
        BuildFilter()
        if _G.DragonUI_UpdateAddonList then _G.DragonUI_UpdateAddonList() end
    end)

    -- SYSTEM INFO BAR
    local InfoBar = CreateFrame("Frame", nil, AddonListFrame)
    InfoBar:SetPoint("TOPLEFT", AddonListFrame, "TOPLEFT", 16, -65)
    InfoBar:SetPoint("TOPRIGHT", AddonListFrame, "TOPRIGHT", -16, -65)
    InfoBar:SetHeight(20)

    local memText = InfoBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    memText:SetPoint("LEFT", 5, 0)

    local timer = 0
    InfoBar:SetScript("OnUpdate", function(self, elapsed)
        timer = timer + elapsed
        if timer >= 1.0 then
            timer = 0
            UpdateAddOnMemoryUsage()
            local totalMem = 0
            for i = 1, GetNumAddOns() do totalMem = totalMem + GetAddOnMemoryUsage(i) end
            memText:SetText(T("Addon Memory:") .. string.format(" %.2f MB", totalMem / 1024))
        end
    end)

    -- FLAT DIVIDER
    local divider = InfoBar:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    divider:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", InfoBar, "BOTTOMLEFT", 0, -2)
    divider:SetPoint("BOTTOMRIGHT", InfoBar, "BOTTOMRIGHT", 0, -2)

    -- LIST CONTAINER
    local ListContainer = CreateFrame("Frame", nil, AddonListFrame)
    ListContainer:SetPoint("TOPLEFT", InfoBar, "BOTTOMLEFT", 0, -10)
    ListContainer:SetPoint("BOTTOMRIGHT", AddonListFrame, "BOTTOMRIGHT", -16, 46)
    ListContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    ListContainer:SetBackdropColor(0.05, 0.04, 0.03, 0.55)
    ListContainer:SetBackdropBorderColor(0, 0, 0, 1)

    -- BOTTOM BUTTONS
    local btnEnableAll = FUI.CreateButton(AddonListFrame, T("Enable All"), 110, 22)
    btnEnableAll:SetPoint("BOTTOMLEFT", AddonListFrame, "BOTTOMLEFT", 16, 14)
    local btnDisableAll = FUI.CreateButton(AddonListFrame, T("Disable All"), 110, 22)
    btnDisableAll:SetPoint("LEFT", btnEnableAll, "RIGHT", 5, 0)
    local btnCancel = FUI.CreateButton(AddonListFrame, T("Cancel"), 80, 22)
    btnCancel:SetPoint("BOTTOMRIGHT", AddonListFrame, "BOTTOMRIGHT", -16, 14)
    local btnOkay = FUI.CreateButton(AddonListFrame, T("OK / Reload"), 100, 22)
    btnOkay:SetPoint("RIGHT", btnCancel, "LEFT", -5, 0)

    -- SCROLL FRAME
    local ScrollFrame = CreateFrame("ScrollFrame", "DragonUI_AddonListScrollFrame", ListContainer, "FauxScrollFrameTemplate")
    ScrollFrame:SetPoint("TOPLEFT", ListContainer, "TOPLEFT", 0, -4)
    ScrollFrame:SetPoint("BOTTOMRIGHT", ListContainer, "BOTTOMRIGHT", -26, 4)
    if FUI.SkinScrollBar then FUI.SkinScrollBar(ScrollFrame) end

    _G.DragonUI_UpdateAddonList = function()
        local numAddons = #filteredAddons
        local offset = FauxScrollFrame_GetOffset(ScrollFrame)
        
        for i = 1, MAX_ADDONS_DISPLAYED do
            local index = offset + i
            local entry = _G["DragonUI_AddonEntry"..i]
            
            if not entry then
                entry = CreateFrame("CheckButton", "DragonUI_AddonEntry"..i, ListContainer)
                entry:SetSize(20, 20)
                entry:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
                entry:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
                entry:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
                
                entry.ExpandBtn = CreateFrame("Button", nil, entry)
                entry.ExpandBtn:SetSize(14, 14)
                entry.ExpandBtn:SetPoint("LEFT", entry, "LEFT", -18, 0)
                entry.ExpandBtn:SetScript("OnClick", function(self)
                    local name = GetAddOnInfo(self:GetParent().addonIndex)
                    collapsedAddons[name] = not collapsedAddons[name]
                    BuildFilter()
                    _G.DragonUI_UpdateAddonList()
                end)

                entry.Icon = entry:CreateTexture(nil, "ARTWORK")
                entry.Icon:SetSize(16, 16)
                entry.Icon:SetPoint("LEFT", entry, "RIGHT", 5, 0)
                
                entry.Text = entry:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                entry.Text:SetPoint("LEFT", entry.Icon, "RIGHT", 8, 0)
                entry.Text:SetWidth(250) 
                entry.Text:SetWordWrap(false)
                entry.Text:SetJustifyH("LEFT")

                entry.Status = entry:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
                entry.Status:SetPoint("RIGHT", ListContainer, "RIGHT", -30, 0)
                entry.Status:SetPoint("TOP", entry, "TOP", 0, -4)
                entry.Status:SetJustifyH("RIGHT")
                
                entry:SetScript("OnClick", function(self)
                    if self:GetChecked() then EnableAddOn(self.addonIndex, character) else DisableAddOn(self.addonIndex, character) end
                    _G.DragonUI_UpdateAddonList()
                end)
                
                entry:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                    local name, title, notes = GetAddOnInfo(self.addonIndex)
                    GameTooltip:AddLine(title or name, 1, 1, 1)
                    if notes then GameTooltip:AddLine(notes, 1, 0.8, 0, true) end
                    GameTooltip:Show()
                end)
                entry:SetScript("OnLeave", function() GameTooltip:Hide() end)
            end
            
            if index <= numAddons then
                local data = filteredAddons[index]
                local realAddonIndex = data.index
                local name, title, notes, enabled, loadable, reason = GetAddOnInfo(realAddonIndex)
                
                entry.addonIndex = realAddonIndex
                entry:SetChecked(enabled)
                entry.Text:SetText(title or name)
                
                local yOffset = -4 - ((i-1) * ADDON_BUTTON_HEIGHT)
                local xOffset = (data.type == "child") and 34 or 24
                entry:ClearAllPoints()
                entry:SetPoint("TOPLEFT", ListContainer, "TOPLEFT", xOffset, yOffset)

                if data.type == "parent" and data.hasChildren then
                    entry.ExpandBtn:Show()
                    entry.ExpandBtn:SetNormalTexture(collapsedAddons[name] and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up")
                    entry.ExpandBtn:SetPushedTexture(collapsedAddons[name] and "Interface\\Buttons\\UI-PlusButton-Down" or "Interface\\Buttons\\UI-MinusButton-Down")
                else
                    entry.ExpandBtn:Hide()
                end
                
                local iconPath = GetAddOnMetadata(realAddonIndex, "IconTexture") or GetAddOnMetadata(realAddonIndex, "Icon")
                entry.Icon:SetTexture(iconPath or "Interface\\Icons\\INV_Box_01")
                
                local parentEnabled = true
                if data.type == "child" and data.parentIndex then
                    -- NATIVE PARENT CHECK
                    local _, _, _, pEnabled = GetAddOnInfo(data.parentIndex)
                    parentEnabled = pEnabled
                end
                
                if not enabled then
                    entry.Text:SetTextColor(0.5, 0.5, 0.5)
                    entry.Status:SetText(T("Disabled"))
                    entry.Status:SetTextColor(0.5, 0.5, 0.5)
                elseif data.type == "child" and not parentEnabled then
                    entry.Text:SetTextColor(1, 0.3, 0.3)
                    entry.Status:SetText(T("Parent Disabled"))
                    entry.Status:SetTextColor(1, 0.3, 0.3)
                elseif not loadable and reason == "INTERFACE_VERSION" then
                    entry.Text:SetTextColor(1, 0.1, 0.1)
                    entry.Status:SetText(T("Out of date"))
                    entry.Status:SetTextColor(1, 0.1, 0.1)
                elseif loadable or enabled then
                    entry.Text:SetTextColor(1, 0.82, 0)
                    entry.Status:SetText(IsAddOnLoadOnDemand(realAddonIndex) and T("Load on Demand") or "")
                    entry.Status:SetTextColor(0.6, 0.6, 0.6)
                end
                
                entry:Show()
            else
                entry:Hide()
            end
        end
        FauxScrollFrame_Update(ScrollFrame, numAddons, MAX_ADDONS_DISPLAYED, ADDON_BUTTON_HEIGHT)
    end

    ScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ADDON_BUTTON_HEIGHT, _G.DragonUI_UpdateAddonList)
    end)

    btnEnableAll:SetScript("OnClick", function() EnableAllAddOns(character); _G.DragonUI_UpdateAddonList() end)
    btnDisableAll:SetScript("OnClick", function() DisableAllAddOns(character); _G.DragonUI_UpdateAddonList() end)
    btnCancel:SetScript("OnClick", function() AddonListFrame:Hide() end)
    btnOkay:SetScript("OnClick", function() ReloadUI() end)
end

local hookMenuFrame = CreateFrame("Frame")
hookMenuFrame:RegisterEvent("PLAYER_LOGIN")
hookMenuFrame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_LOGIN" then
        BuildWindow()
        
        local menuBtn = CreateFrame("Button", "GameMenuButtonDragonUIAddons", GameMenuFrame, "GameMenuButtonTemplate")
        menuBtn:SetText(T("AddOns"))
        
        if DUI and DUI.PanelControls and DUI.PanelControls.SkinButton then
            DUI.PanelControls.SkinButton({frame = menuBtn})
        end
        
        menuBtn:SetScript("OnClick", function()
            HideUIPanel(GameMenuFrame)
            searchText = ""
            if _G.DragonUI_AddonList_Search and _G.DragonUI_AddonList_Search.ClearFocus then 
                _G.DragonUI_AddonList_Search:SetText("") 
            end
            BuildFilter()
            if _G.DragonUI_UpdateAddonList then _G.DragonUI_UpdateAddonList() end
            if AddonListFrame then AddonListFrame:Show() end
        end)
        
        GameMenuFrame:HookScript("OnShow", function(menu)
            menuBtn:SetPoint("TOP", GameMenuButtonMacros, "BOTTOM", 0, -1)
            local pushTarget = menuBtn
            if GameMenuButtonRatings and GameMenuButtonRatings:IsShown() then
                GameMenuButtonRatings:ClearAllPoints()
                GameMenuButtonRatings:SetPoint("TOP", menuBtn, "BOTTOM", 0, -1)
                pushTarget = GameMenuButtonRatings
            end
            GameMenuButtonLogout:ClearAllPoints()
            GameMenuButtonLogout:SetPoint("TOP", pushTarget, "BOTTOM", 0, -16)
            menu:SetHeight(menu:GetHeight() + menuBtn:GetHeight() + 1)
        end)
        
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)