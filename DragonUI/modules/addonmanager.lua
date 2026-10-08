local addon = select(2, ...)
local L = addon.L

local AddonManagerModule = { initialized = false, applied = false }

local AddonListFrame
local searchBox
local snapshot = {}
local applied = false
local filteredAddons = {}
local collapsedAddons = {}
local searchText = ""
local addonRows = {}
local hierarchy = {}
local MAX_ADDONS_DISPLAYED = 15
local ADDON_BUTTON_HEIGHT = 22

local TEXT_ADDONS = _G.ADDONS or "AddOns"
local TEXT_CANCEL = _G.CANCEL or "Cancel"
local TEXT_DISABLED = _G.ADDON_DISABLED or "Disabled"
local TEXT_LOD = _G.ADDON_DEMAND_LOADED or "Load on Demand"
local TEXT_PROTECTED = L["Protected"] or "Protected"

local function BuildHierarchy()
    wipe(hierarchy)
    local numAddons = GetNumAddOns()
    local indexByName = {}
    
    for i = 1, numAddons do
        local n = GetAddOnInfo(i)
        if n then indexByName[n:lower()] = i end
    end
    
    local parents = {}
    local childrenMap = {}
    
    local function GetUltimateParent(idx)
        local visited = {}
        local current = idx
        while current do
            if visited[current] then break end
            visited[current] = true
            local dep = GetAddOnDependencies(current)
            local found = dep and indexByName[dep:lower()]
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
        table.insert(hierarchy, { type = "parent", index = pIndex, children = childrenMap[pIndex] })
    end
end

local function Matches(name, title, query)
    return (name and name:lower():find(query, 1, true)) or (title and title:lower():find(query, 1, true))
end

local function ApplyFilter()
    wipe(filteredAddons)
    local query = searchText:lower()
    
    for _, pData in ipairs(hierarchy) do
        local pName, pTitle = GetAddOnInfo(pData.index)
        local pMatch = (query == "") or Matches(pName, pTitle, query)
        local hasMatchingChild = false
        
        if not pMatch and pData.children then
            for _, cIndex in ipairs(pData.children) do
                local cName, cTitle = GetAddOnInfo(cIndex)
                if Matches(cName, cTitle, query) then
                    hasMatchingChild = true
                    break
                end
            end
        end
        
        if pMatch or hasMatchingChild then
            table.insert(filteredAddons, { type = "parent", index = pData.index, hasChildren = (pData.children ~= nil) })
            if pData.children and not collapsedAddons[pName] then
                for _, cIndex in ipairs(pData.children) do
                    local cName, cTitle = GetAddOnInfo(cIndex)
                    if query == "" or pMatch or Matches(cName, cTitle, query) then
                        table.insert(filteredAddons, { type = "child", index = cIndex, parentIndex = pData.index })
                    end
                end
            end
        end
    end
end

local function TakeSnapshot()
    wipe(snapshot)
    for i = 1, GetNumAddOns() do
        local name = GetAddOnInfo(i)
        if name == "DragonUI" or name == "DragonUI_Options" then
            snapshot[i] = true
        else
            snapshot[i] = select(4, GetAddOnInfo(i)) and true or false
        end
    end
    applied = false
end

local function RestoreSnapshot()
    if applied then return end
    for i, wasEnabled in ipairs(snapshot) do
        local name = GetAddOnInfo(i)
        if name ~= "DragonUI" and name ~= "DragonUI_Options" then
            if wasEnabled then EnableAddOn(i) else DisableAddOn(i) end
        end
    end
end

local UpdateAddonList

UpdateAddonList = function()
    local numAddons = #filteredAddons
    local offset = FauxScrollFrame_GetOffset(AddonListFrame.ScrollFrame)
    
    for i = 1, MAX_ADDONS_DISPLAYED do
        local index = offset + i
        local entry = addonRows[i]
        
        if not entry then
            entry = CreateFrame("CheckButton", nil, AddonListFrame.ListContainer)
            entry:SetSize(20, 20)
            entry:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
            entry:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
            entry:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
            entry:SetDisabledTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
            
            entry.ExpandBtn = CreateFrame("Button", nil, entry)
            entry.ExpandBtn:SetSize(14, 14)
            entry.ExpandBtn:SetPoint("LEFT", entry, "LEFT", -18, 0)
            entry.ExpandBtn:SetScript("OnClick", function(self)
                local name = GetAddOnInfo(self:GetParent().addonIndex)
                collapsedAddons[name] = not collapsedAddons[name]
                ApplyFilter()
                UpdateAddonList()
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
            entry.Status:SetPoint("RIGHT", AddonListFrame.ListContainer, "RIGHT", -30, 0)
            entry.Status:SetPoint("TOP", entry, "TOP", 0, -4)
            entry.Status:SetJustifyH("RIGHT")
            
            entry:SetScript("OnClick", function(self)
                if self:GetChecked() then EnableAddOn(self.addonIndex) else DisableAddOn(self.addonIndex) end
                UpdateAddonList()
            end)
            
            entry:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                local name, title, notes = GetAddOnInfo(self.addonIndex)
                GameTooltip:AddLine(title or name, 1, 1, 1)
                if notes then GameTooltip:AddLine(notes, 1, 0.8, 0, true) end
                GameTooltip:Show()
            end)
            entry:SetScript("OnLeave", function() GameTooltip:Hide() end)
            
            addonRows[i] = entry
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
            entry:SetPoint("TOPLEFT", AddonListFrame.ListContainer, "TOPLEFT", xOffset, yOffset)

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
            local deps = {GetAddOnDependencies(realAddonIndex)}
            for _, dep in ipairs(deps) do
                if not select(4, GetAddOnInfo(dep)) then
                    parentEnabled = false
                    break
                end
            end
            
            local isProtected = (name == "DragonUI" or name == "DragonUI_Options")
            
            if isProtected then
                entry:Disable()
                entry:SetChecked(true)
                entry.Text:SetTextColor(1, 0.82, 0)
                entry.Status:SetText(TEXT_PROTECTED)
                entry.Status:SetTextColor(0.5, 0.5, 0.5)
            elseif not enabled then
                entry:Enable()
                entry.Text:SetTextColor(0.5, 0.5, 0.5)
                entry.Status:SetText(TEXT_DISABLED)
                entry.Status:SetTextColor(0.5, 0.5, 0.5)
            elseif not parentEnabled then
                entry:Enable()
                entry.Text:SetTextColor(1, 0.3, 0.3)
                entry.Status:SetText(L["Parent Disabled"] or "Parent Disabled")
                entry.Status:SetTextColor(1, 0.3, 0.3)
            elseif not loadable and reason then
                entry:Enable()
                entry.Text:SetTextColor(1, 0.1, 0.1)
                entry.Status:SetText(_G["ADDON_" .. reason] or reason)
                entry.Status:SetTextColor(1, 0.1, 0.1)
            else
                entry:Enable()
                entry.Text:SetTextColor(1, 0.82, 0)
                entry.Status:SetText(IsAddOnLoadOnDemand(realAddonIndex) and TEXT_LOD or "")
                entry.Status:SetTextColor(0.6, 0.6, 0.6)
            end
            
            entry:Show()
        else
            entry:Hide()
        end
    end
    FauxScrollFrame_Update(AddonListFrame.ScrollFrame, numAddons, MAX_ADDONS_DISPLAYED, ADDON_BUTTON_HEIGHT)
end

local function BuildWindow()
    AddonListFrame = addon.ForeverUI.CreateWindow("DragonUI_AddonList", UIParent, {
        width    = 620,
        height   = 479,
        title    = L["Addon Manager"] or "Addon Manager",
        strata   = "DIALOG",
        movable  = true,
        escClose = true,
        closable = true,
        inset    = false,
    })
    AddonListFrame:SetPoint("CENTER")
    AddonListFrame:SetScript("OnHide", RestoreSnapshot)
    
    local cbOutOfDate = CreateFrame("CheckButton", nil, AddonListFrame, "UICheckButtonTemplate")
    cbOutOfDate:SetSize(24, 24)
    cbOutOfDate:SetPoint("TOPLEFT", AddonListFrame, "TOPLEFT", 14, -33)
    cbOutOfDate.text = cbOutOfDate:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    cbOutOfDate.text:SetPoint("LEFT", cbOutOfDate, "RIGHT", 4, 0)
    cbOutOfDate.text:SetText(L["Load out of date AddOns"] or "Load out of date AddOns")
    cbOutOfDate:SetChecked(GetCVar("checkAddonVersion") == "0")
    cbOutOfDate:SetScript("OnClick", function(self) SetCVar("checkAddonVersion", self:GetChecked() and "0" or "1") end)

    searchBox = addon.ForeverUI.CreateSearchBox(AddonListFrame, 160, L["Search..."] or "Search...")
    searchBox:SetPoint("TOPRIGHT", AddonListFrame, "TOPRIGHT", -16, -35)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText()
        ApplyFilter()
        UpdateAddonList()
    end)

    local InfoBar = CreateFrame("Frame", nil, AddonListFrame)
    InfoBar:SetPoint("TOPLEFT", AddonListFrame, "TOPLEFT", 16, -65)
    InfoBar:SetPoint("TOPRIGHT", AddonListFrame, "TOPRIGHT", -16, -65)
    InfoBar:SetHeight(20)

    local memText = InfoBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    memText:SetPoint("LEFT", 5, 0)
    
    local timer = 15
    local function RefreshMemory()
        UpdateAddOnMemoryUsage()
        local totalMem = 0
        for i = 1, GetNumAddOns() do totalMem = totalMem + GetAddOnMemoryUsage(i) end
        memText:SetText((L["Addon Memory:"] or "Addon Memory:") .. string.format(" %.2f MB", totalMem / 1024))
    end
    
    AddonListFrame:HookScript("OnShow", RefreshMemory)
    InfoBar:SetScript("OnUpdate", function(self, elapsed)
        timer = timer + elapsed
        if timer >= 15.0 then
            timer = 0
            RefreshMemory()
        end
    end)

    local divider = InfoBar:CreateTexture(nil, "ARTWORK")
    divider:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
    divider:SetVertexColor(0.3, 0.3, 0.3, 0.5)
    divider:SetHeight(1)
    divider:SetPoint("BOTTOMLEFT", InfoBar, "BOTTOMLEFT", 0, -2)
    divider:SetPoint("BOTTOMRIGHT", InfoBar, "BOTTOMRIGHT", 0, -2)

    AddonListFrame.ListContainer = CreateFrame("Frame", nil, AddonListFrame)
    AddonListFrame.ListContainer:SetPoint("TOPLEFT", InfoBar, "BOTTOMLEFT", 0, -10)
    AddonListFrame.ListContainer:SetPoint("BOTTOMRIGHT", AddonListFrame, "BOTTOMRIGHT", -16, 46)
    AddonListFrame.ListContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    AddonListFrame.ListContainer:SetBackdropColor(0.05, 0.04, 0.03, 0.55)
    AddonListFrame.ListContainer:SetBackdropBorderColor(0, 0, 0, 1)

    local btnEnableAll = addon.ForeverUI.CreateButton(AddonListFrame, L["Enable All"] or "Enable All", 110, 22)
    btnEnableAll:SetPoint("BOTTOMLEFT", AddonListFrame, "BOTTOMLEFT", 16, 14)
    btnEnableAll:SetScript("OnClick", function() EnableAllAddOns(); UpdateAddonList() end)
    
    local btnDisableAll = addon.ForeverUI.CreateButton(AddonListFrame, L["Disable All"] or "Disable All", 110, 22)
    btnDisableAll:SetPoint("LEFT", btnEnableAll, "RIGHT", 5, 0)
    btnDisableAll:SetScript("OnClick", function()
        for i = 1, GetNumAddOns() do
            local n = GetAddOnInfo(i)
            if n ~= "DragonUI" and n ~= "DragonUI_Options" then
                DisableAddOn(i)
            end
        end
        UpdateAddonList()
    end)
    
    local btnCancel = addon.ForeverUI.CreateButton(AddonListFrame, TEXT_CANCEL, 80, 22)
    btnCancel:SetPoint("BOTTOMRIGHT", AddonListFrame, "BOTTOMRIGHT", -16, 14)
    btnCancel:SetScript("OnClick", function() AddonListFrame:Hide() end)
    
    local btnOkay = addon.ForeverUI.CreateButton(AddonListFrame, L["OK / Reload"] or "OK / Reload", 100, 22)
    btnOkay:SetPoint("RIGHT", btnCancel, "LEFT", -5, 0)
    btnOkay:SetScript("OnClick", function() applied = true; ReloadUI() end)

    AddonListFrame.ScrollFrame = CreateFrame("ScrollFrame", "DragonUI_AddonListScrollFrame", AddonListFrame.ListContainer, "FauxScrollFrameTemplate")
    AddonListFrame.ScrollFrame:SetPoint("TOPLEFT", AddonListFrame.ListContainer, "TOPLEFT", 0, -4)
    AddonListFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", AddonListFrame.ListContainer, "BOTTOMRIGHT", -26, 4)
    if addon.ForeverUI.SkinScrollBar then addon.ForeverUI.SkinScrollBar(AddonListFrame.ScrollFrame) end
    
    AddonListFrame.ScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ADDON_BUTTON_HEIGHT, UpdateAddonList)
    end)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    
    if not addon:IsModuleEnabled("addonmanager") then return end
    if _G.GameMenuButtonAddons then return end
    
    local menuBtn = CreateFrame("Button", "GameMenuButtonDragonUIAddons", GameMenuFrame, "GameMenuButtonTemplate")
    menuBtn:SetText(TEXT_ADDONS)
    
    if addon.ForeverUI and addon.ForeverUI.SkinButton then
        addon.ForeverUI.SkinButton(menuBtn)
    end
    
    menuBtn:SetPoint("TOP", GameMenuButtonMacros, "BOTTOM", 0, -1)
    if GameMenuButtonRatings then
        GameMenuButtonRatings:ClearAllPoints()
        GameMenuButtonRatings:SetPoint("TOP", menuBtn, "BOTTOM", 0, -1)
    end
    GameMenuButtonLogout:ClearAllPoints()
    GameMenuButtonLogout:SetPoint("TOP", menuBtn, "BOTTOM", 0, -1)
    GameMenuFrame:SetHeight(GameMenuFrame:GetHeight() + menuBtn:GetHeight() + 1)
    
    menuBtn:SetScript("OnClick", function()
        HideUIPanel(GameMenuFrame)
        if not AddonListFrame then BuildWindow() end
        
        TakeSnapshot()
        searchText = ""
        if searchBox then searchBox:SetText("") end
        BuildHierarchy()
        ApplyFilter()
        UpdateAddonList()
        
        AddonListFrame:Show()
    end)
end)

addon:RegisterModule("addonmanager", AddonManagerModule,
    L["Addon Manager"] or "Addon Manager",
    "In-game addon management interface",
    { lifecyclePrefix = "AddonManager", loadOnce = true })