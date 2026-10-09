local addon = select(2, ...)
local L = addon.L

local AddonManagerModule = { initialized = false, applied = false }

local AddonListFrame
local searchBox
local outOfDateCheck
local snapshot = {}
local snapshotCheckVersion
local applied = false
local filteredAddons = {}
local collapsedAddons = {}
local searchText = ""
local addonRows = {}
local hierarchy = {}
local ADDON_BUTTON_HEIGHT = 22
local LIST_TOP, LIST_BOTTOM = 95, 46
local WINDOW_WIDTH, WINDOW_HEIGHT = 620, 479
local WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT = 520, 300
local WINDOW_MAX_WIDTH, WINDOW_MAX_HEIGHT = 1400, 1000
local SCALE_STEPS = { 0.75, 0.9, 1, 1.1, 1.25, 1.5, 1.75, 2 }

local DRAGONUI_ICON = { icon = "Interface\\AddOns\\DragonUI\\Textures\\UI\\INV_Misc_Head_Dragon_01", crop = true }
local FALLBACK_ICON = { icon = "Interface\\Icons\\INV_Box_01" }

-- ============================================================================
-- ICONS
-- ============================================================================

local brokerWatcher = {}
local brokerCreators = {}
local liveIcons = {}
local buttonIcons = {}
local chosenIcons = {}

local function PlainText(text)
    return (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|T.-|t", ""))
end

local function IconCache()
    local global = addon.db and addon.db.global
    if not global then return {} end
    global.addonIcons = global.addonIcons or {}
    return global.addonIcons
end

-- Art shipped in an addon's own folder, outside its libraries, can only be that addon's.
local function FolderOf(path)
    local folder, rest = path:lower():gsub("/", "\\"):match("^interface\\addons\\([^\\]+)\\(.+)$")
    if folder and not ("\\" .. rest):find("\\lib", 1, true) then
        return folder
    end
end

-- The frame right below LibDataBroker's NewDataObject is the code that created the launcher.
local function CreatorFolder(stack)
    local afterBroker = false
    for line in stack:gmatch("[^\n]+") do
        if line:lower():find("databroker%-1%.1[^:]*:%d+:") then
            afterBroker = true
        elseif afterBroker then
            local path = line:match("^(.-):%d+:")
            return path and FolderOf(path)
        end
    end
end

local function WatchBrokers()
    if brokerWatcher.on then return end
    local ldb = LibStub("LibDataBroker-1.1", true)
    if not (ldb and ldb.RegisterCallback) then return end
    brokerWatcher.on = true
    ldb.RegisterCallback(brokerWatcher, "LibDataBroker_DataObjectCreated", function(_, name)
        brokerCreators[name] = CreatorFolder(debugstack())
    end)
end

local function ValidCoords(coords)
    if type(coords) ~= "table" then return false end
    for i = 1, 4 do
        if type(coords[i]) ~= "number" then return false end
    end
    return true
end

local function IconSpec(object)
    local icon = object and object.icon
    if type(icon) ~= "string" or icon == "" then return end
    local coords = object.iconCoords
    if ValidCoords(coords) then
        return { icon = icon, coords = { coords[1], coords[2], coords[3], coords[4] } }
    end
    return { icon = icon }
end

local function Prefer(candidates, folder, plain)
    if not candidates then return end
    for _, candidate in ipairs(candidates) do
        local key = candidate.name:lower()
        if key == folder or key == plain then return candidate.spec end
    end
    return candidates[1].spec
end

local CHROME_WORDS = { "border", "highlight", "background", "backdrop", "mask", "glow", "ring" }

local function IsChrome(path)
    local file = path:lower():match("([^\\/]+)$") or ""
    for _, word in ipairs(CHROME_WORDS) do
        if file:find(word, 1, true) then return true end
    end
end

local function ButtonArt(button)
    local name = button:GetName()
    local regions = {}
    local preferred = { button.icon, button.Icon, name and _G[name .. "Icon"], button:GetNormalTexture() }
    for i = 1, 4 do
        if preferred[i] then regions[#regions + 1] = preferred[i] end
    end
    for _, region in ipairs({ button:GetRegions() }) do
        regions[#regions + 1] = region
    end
    for _, region in ipairs(regions) do
        if type(region) == "table" and region.GetObjectType and region:GetObjectType() == "Texture" then
            local path = region:GetTexture()
            local folder = type(path) == "string" and FolderOf(path)
            if folder and folder ~= "dragonui" and not IsChrome(path) then
                return folder, path
            end
        end
    end
end

-- Map pins are numbered or anonymous and many only show tooltips; a launcher is named and clickable.
local function IsLauncherButton(button)
    local name = button:GetName()
    if not name or name:find("%d$") then return false end
    return button:GetScript("OnClick") or button:GetScript("OnMouseUp") or button:GetScript("OnMouseDown")
end

-- Minimap buttons of loaded addons that have no LibDataBroker launcher; only art in a folder names its owner.
local function ScanMinimapButtons()
    local frames = addon.MinimapModule and addon.MinimapModule.frames
    local holders = { Minimap, MinimapBackdrop, frames and frames.iconCollector }
    local cache = IconCache()
    local function Visit(holder, nested)
        local ok, children = pcall(function() return { holder:GetChildren() } end)
        if not ok then return end
        for _, child in ipairs(children) do
            local kind = child:GetObjectType()
            if kind == "Button" and IsLauncherButton(child) then
                local folder, path = ButtonArt(child)
                if folder and not buttonIcons[folder] then
                    buttonIcons[folder] = { icon = path, weak = true }
                    local saved = cache[folder]
                    if not (type(saved) == "table" and not saved.weak) then
                        cache[folder] = buttonIcons[folder]
                    end
                end
            elseif kind == "Frame" and not nested then
                Visit(child, true)
            end
        end
    end
    for i = 1, 3 do
        if holders[i] then Visit(holders[i], false) end
    end
end

local function ScanBrokers()
    local ldb = LibStub("LibDataBroker-1.1", true)
    if not ldb then return end

    local names = {}
    for name in ldb:DataObjectIterator() do
        names[#names + 1] = name
    end
    table.sort(names)

    local byCreator, byArt, byName = {}, {}, {}
    local function Offer(map, folder, name, spec)
        map[folder] = map[folder] or {}
        table.insert(map[folder], { name = name, spec = spec })
    end
    for _, name in ipairs(names) do
        local spec = IconSpec(ldb:GetDataObjectByName(name))
        if spec then
            if brokerCreators[name] then Offer(byCreator, brokerCreators[name], name, spec) end
            local owner = FolderOf(spec.icon)
            if owner then Offer(byArt, owner, name, spec) end
            byName[name:lower()] = byName[name:lower()] or spec
        end
    end

    local cache = IconCache()
    for i = 1, GetNumAddOns() do
        local folder, title = GetAddOnInfo(i)
        if folder then
            local key = folder:lower()
            local plain = PlainText(title or folder):lower()
            local spec = Prefer(byCreator[key], key, plain) or Prefer(byArt[key], key, plain) or byName[key] or byName[plain]
            if spec then
                liveIcons[key] = spec
                cache[key] = spec
            end
        end
    end
end

-- Uninstalled addons would otherwise stay in the SavedVariables forever.
local function PruneIconCache()
    local installed = {}
    for i = 1, GetNumAddOns() do
        local folder = GetAddOnInfo(i)
        if folder then installed[folder:lower()] = true end
    end
    local cache = IconCache()
    for key in pairs(cache) do
        if not installed[key] then cache[key] = nil end
    end
end

local function ScanLiveIcons()
    wipe(liveIcons)
    wipe(buttonIcons)
    wipe(chosenIcons)
    ScanBrokers()
    ScanMinimapButtons()
    PruneIconCache()
end

local VERSION_SUFFIXES = { "wotlk", "335", "3.3.5", "3.3.5a", "main", "master", "epoch", "fixed", "warmane" }

-- "Questie-335" or "pfQuest-wotlk" are the same addon as the table's "questie" and "pfquest".
local function KnownEntry(folder)
    local known = addon.AddonManagerKnownIcons or {}
    local key = folder:lower()
    if known[key] then return known[key] end
    key = key:gsub("^[!_]+", "")
    local trimmed = true
    while trimmed do
        trimmed = false
        for _, suffix in ipairs(VERSION_SUFFIXES) do
            local base = key:match("^(.-)[%-_ %.]+" .. suffix:gsub("%.", "%%.") .. "$")
            if base and base ~= "" then
                key, trimmed = base, true
            end
        end
    end
    return known[key]
end

local function KnownSpec(folder, entry)
    local path = type(entry) == "table" and entry[1] or entry
    if not path:lower():find("^interface\\") then
        path = "Interface\\AddOns\\" .. folder .. "\\" .. path
    end
    if type(entry) == "table" and entry[2] then
        return { icon = path, coords = { entry[2], entry[3], entry[4], entry[5] } }
    end
    return { icon = path }
end

-- An entry may list alternatives: builds of one addon that ship different art under the same folder.
local function KnownIcon(folder)
    local entry = KnownEntry(folder)
    if not entry then return end
    if type(entry) == "table" and type(entry[1]) == "table" then
        local alternatives = {}
        for i, alternative in ipairs(entry) do
            alternatives[i] = KnownSpec(folder, alternative)
        end
        return alternatives
    end
    return KnownSpec(folder, entry)
end

local PROBE_DIRS = { "", "Media\\", "Media\\Textures\\", "Textures\\", "Images\\", "Img\\", "Icons\\", "Art\\", "Artwork\\", "Skin\\" }
local probeResults = {}
local prober, probeWorks

local function Prober()
    if prober == nil then
        local holder = CreateFrame("Frame", nil, UIParent)
        holder:Hide()
        prober = holder:CreateTexture(nil, "ARTWORK")
        prober:SetPoint("CENTER")
        -- SetTexture's answer only proves a file exists if it refuses one that cannot.
        probeWorks = not prober:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\no-such-file-probe")
    end
    return probeWorks and prober
end

-- Logos can be wide banners: only one that an unsized texture measures as square gets through.
local function IsSquare(texture)
    local width, height = texture:GetWidth(), texture:GetHeight()
    return width > 0 and height > 0 and math.abs(width - height) <= 0.15 * math.max(width, height)
end

local function ProbeAt(texture, root, name, needsSquare)
    for _, dir in ipairs(PROBE_DIRS) do
        local path = root .. dir .. name
        if texture:SetTexture(path) and (not needsSquare or IsSquare(texture)) then
            return { icon = path }
        end
    end
end

-- Files on disk answer even for an addon that is disabled and has never run.
local function ProbeFolder(folder)
    local key = folder:lower()
    if probeResults[key] == nil then
        local texture = Prober()
        local found
        if texture then
            local root = "Interface\\AddOns\\" .. folder .. "\\"
            local base = folder:gsub("^[!_]+", ""):gsub("[-_].*$", "")
            local initials = folder:gsub("[^A-Z]", "")
            local names = { "icon" }
            if base ~= "" then names[#names + 1] = base .. "Icon" end
            if #initials >= 2 then names[#names + 1] = initials .. "Icon" end
            names[#names + 1] = "Minimap-Button-Up"
            names[#names + 1] = "MinimapButton"
            names[#names + 1] = "MinimapIcon"
            for _, name in ipairs(names) do
                found = ProbeAt(texture, root, name)
                if found then break end
            end
            -- Titan plugins ship their icon as <Folder>\<Folder>; no other art in the surveyed addons is named so.
            if not found and texture:SetTexture(root .. folder) then
                found = { icon = root .. folder }
            end
            found = found or ProbeAt(texture, root, "logo", true)
            texture:SetTexture(nil)
        end
        probeResults[key] = found or false
    end
    return probeResults[key] or nil
end

-- Most trusted first; a source whose file is missing on this install falls through to the next one.
local ICON_SOURCES = {
    function(_, name)
        if name == "DragonUI" or name == "DragonUI_Options" then return DRAGONUI_ICON end
    end,
    function(index)
        local declared = GetAddOnMetadata(index, "X-IconTexture") or GetAddOnMetadata(index, "X-Icon")
        if declared and declared ~= "" then return { icon = declared } end
    end,
    function(_, name) return liveIcons[name:lower()] end,
    function(_, name)
        local saved = IconCache()[name:lower()]
        if type(saved) == "table" and not saved.weak then return saved end
    end,
    function(_, name) return KnownIcon(name) end,
    function(_, name) return buttonIcons[name:lower()] or IconCache()[name:lower()] end,
    function(_, name) return ProbeFolder(name) end,
}

local function Initial(text)
    for char in PlainText(text):gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if char:find("^[%w\194-\244]") then
            return char:upper()
        end
    end
end

local function NameColor(name)
    local hash = 0
    for i = 1, #name do
        hash = (hash * 31 + name:byte(i)) % 360
    end
    local h, s, v = hash / 60, 0.45, 0.55
    local sector = math.floor(h)
    local f = h - sector
    local p, q, t = v * (1 - s), v * (1 - s * f), v * (1 - s * (1 - f))
    if sector == 0 then return v, t, p end
    if sector == 1 then return q, v, p end
    if sector == 2 then return p, v, t end
    if sector == 3 then return p, q, v end
    if sector == 4 then return t, p, v end
    return v, p, q
end

-- Cached specs come back from SavedVariables, so nothing about their shape is taken on trust.
local function ShowIcon(row, spec)
    local icon = row.Icon
    if not (type(spec) == "table" and type(spec.icon) == "string" and icon:SetTexture(spec.icon)) then return false end
    local coords = spec.coords
    if ValidCoords(coords) then
        icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    elseif spec.crop or spec.icon:lower():gsub("/", "\\"):find("^interface\\icons\\") then
        icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end
    row.Letter:Hide()
    return true
end

local function ShowAnyIcon(row, found)
    if type(found) ~= "table" then return end
    if found.icon then return ShowIcon(row, found) and found end
    for _, spec in ipairs(found) do
        if ShowIcon(row, spec) then return spec end
    end
end

local function ShowAddonIcon(row, index)
    local name = GetAddOnInfo(index)
    for _, source in ipairs(ICON_SOURCES) do
        local shown = ShowAnyIcon(row, source(index, name))
        if shown then return shown end
    end
end

-- Resolved once per opening: scrolling and resizing repaint rows far more often than icons can change.
local function SetRowIcon(row, data, name, label)
    local chosen = chosenIcons[data.index]
    if chosen == nil then
        chosen = ShowAddonIcon(row, data.index) or (data.parentIndex and ShowAddonIcon(row, data.parentIndex)) or false
        chosenIcons[data.index] = chosen
    elseif chosen then
        ShowIcon(row, chosen)
    end
    if chosen then return end
    local letter = Initial(label) or Initial(name)
    if not letter then
        ShowIcon(row, FALLBACK_ICON)
        return
    end
    row.Icon:SetTexture(NameColor(name:lower()))
    row.Icon:SetTexCoord(0, 1, 0, 1)
    row.Letter:SetText(letter)
    row.Letter:Show()
end

-- ============================================================================
-- LIST
-- ============================================================================

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
        if GetAddOnInfo(i) == "DragonUI" then
            snapshot[i] = true
        else
            snapshot[i] = select(4, GetAddOnInfo(i)) and true or false
        end
    end
    snapshotCheckVersion = GetCVar("checkAddonVersion")
    applied = false
end

local function RestoreSnapshot()
    if applied then return end
    for i, wasEnabled in ipairs(snapshot) do
        if GetAddOnInfo(i) ~= "DragonUI" then
            if wasEnabled then EnableAddOn(i) else DisableAddOn(i) end
        end
    end
    SetCVar("checkAddonVersion", snapshotCheckVersion)
end

local UpdateAddonList
local shownRows

-- The quest tracker's collapse toggle, so both lists fold with the same button.
local function SkinToggleTexture(texture, atlas, blend)
    local file, _, _, left, right, top, bottom = addon.functions.UnpackAtlas(atlas)
    texture:SetTexture(file)
    texture:SetTexCoord(left, right, top, bottom)
    if blend then texture:SetBlendMode(blend) end
end

local function VisibleRows()
    local height = AddonListFrame:GetHeight() - LIST_TOP - LIST_BOTTOM - 8
    return math.max(1, math.floor(height / ADDON_BUTTON_HEIGHT))
end

local function CreateRow(i)
    local container = AddonListFrame.ListContainer
    local row = CreateFrame("Frame", nil, container)
    row:SetHeight(ADDON_BUTTON_HEIGHT)
    local y = -4 - (i - 1) * ADDON_BUTTON_HEIGHT
    row:SetPoint("TOPLEFT", container, "TOPLEFT", 0, y)
    row:SetPoint("TOPRIGHT", container, "TOPRIGHT", -30, y)

    local check = CreateFrame("CheckButton", nil, row)
    check:SetSize(20, 20)
    check:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
    check:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
    check:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
    check:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
    row.Check = check

    check.ExpandBtn = CreateFrame("Button", nil, check)
    check.ExpandBtn:SetSize(13, 14)
    check.ExpandBtn:SetPoint("LEFT", check, "LEFT", -17, 0)
    local toggleFile = addon.functions.UnpackAtlas("QuestTracker-Collapse")
    check.ExpandBtn:SetNormalTexture(toggleFile)
    check.ExpandBtn:SetPushedTexture(toggleFile)
    check.ExpandBtn:SetHighlightTexture(toggleFile)
    SkinToggleTexture(check.ExpandBtn:GetHighlightTexture(), "QuestTracker-Red-Highlight", "ADD")
    check.ExpandBtn:SetScript("OnClick", function(self)
        local name = GetAddOnInfo(self:GetParent().addonIndex)
        collapsedAddons[name] = not collapsedAddons[name]
        ApplyFilter()
        UpdateAddonList()
    end)

    row.Icon = row:CreateTexture(nil, "ARTWORK")
    row.Icon:SetSize(16, 16)
    row.Icon:SetPoint("LEFT", check, "RIGHT", 5, 0)

    row.Letter = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.Letter:SetPoint("CENTER", row.Icon, "CENTER", 0, 0)

    row.Status = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.Status:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    row.Status:SetJustifyH("RIGHT")

    row.Text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.Text:SetPoint("LEFT", row.Icon, "RIGHT", 8, 0)
    row.Text:SetPoint("RIGHT", row.Status, "LEFT", -10, 0)
    row.Text:SetWordWrap(false)
    row.Text:SetJustifyH("LEFT")

    check:SetScript("OnClick", function(self)
        if self:GetChecked() then EnableAddOn(self.addonIndex) else DisableAddOn(self.addonIndex) end
        UpdateAddonList()
    end)

    check:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        local name, title, notes = GetAddOnInfo(self.addonIndex)
        GameTooltip:AddLine(title or name, 1, 1, 1)
        if notes then GameTooltip:AddLine(notes, 1, 0.8, 0, true) end
        GameTooltip:Show()
    end)
    check:SetScript("OnLeave", function() GameTooltip:Hide() end)

    addonRows[i] = row
    return row
end

local function FillRow(row, data)
    local index = data.index
    local name, title, _, enabled, loadable, reason = GetAddOnInfo(index)
    local check = row.Check

    check.addonIndex = index
    check:SetChecked(enabled)
    check:ClearAllPoints()
    check:SetPoint("LEFT", row, "LEFT", (data.type == "child") and 34 or 24, 0)
    row.Text:SetText(title or name)
    SetRowIcon(row, data, name, title or name)

    if data.type == "parent" and data.hasChildren then
        local state = collapsedAddons[name] and "QuestTracker-Expand" or "QuestTracker-Collapse"
        SkinToggleTexture(check.ExpandBtn:GetNormalTexture(), state)
        SkinToggleTexture(check.ExpandBtn:GetPushedTexture(), state .. "-Pressed")
        check.ExpandBtn:Show()
    else
        check.ExpandBtn:Hide()
    end

    local parentEnabled = true
    local deps = {GetAddOnDependencies(index)}
    for _, dep in ipairs(deps) do
        if not select(4, GetAddOnInfo(dep)) then
            parentEnabled = false
            break
        end
    end

    if name == "DragonUI" then
        check:Disable()
        check:SetChecked(true)
        row.Text:SetTextColor(1, 0.82, 0)
        row.Status:SetText(L["Protected"])
        row.Status:SetTextColor(0.5, 0.5, 0.5)
    elseif not enabled then
        check:Enable()
        row.Text:SetTextColor(0.5, 0.5, 0.5)
        row.Status:SetText(ADDON_DISABLED)
        row.Status:SetTextColor(0.5, 0.5, 0.5)
    elseif not loadable and reason then
        check:Enable()
        row.Text:SetTextColor(1, 0.1, 0.1)
        row.Status:SetText(_G["ADDON_" .. reason] or reason)
        row.Status:SetTextColor(1, 0.1, 0.1)
    elseif not parentEnabled then
        check:Enable()
        row.Text:SetTextColor(1, 0.3, 0.3)
        row.Status:SetText(L["Parent Disabled"])
        row.Status:SetTextColor(1, 0.3, 0.3)
    else
        check:Enable()
        row.Text:SetTextColor(1, 0.82, 0)
        row.Status:SetText(IsAddOnLoadOnDemand(index) and ADDON_DEMAND_LOADED or "")
        row.Status:SetTextColor(0.6, 0.6, 0.6)
    end
end

UpdateAddonList = function()
    local scrollFrame = AddonListFrame.ScrollFrame
    local numAddons = #filteredAddons
    local numRows = VisibleRows()
    shownRows = numRows
    -- A taller window shows more rows, so an offset near the end may now leave the bottom ones empty.
    local offset = math.min(FauxScrollFrame_GetOffset(scrollFrame) or 0, math.max(0, numAddons - numRows))
    FauxScrollFrame_SetOffset(scrollFrame, offset)

    for i = 1, math.max(numRows, #addonRows) do
        local row = addonRows[i]
        if i <= numRows and offset + i <= numAddons then
            row = row or CreateRow(i)
            FillRow(row, filteredAddons[offset + i])
            row:Show()
        elseif row then
            row:Hide()
        end
    end
    FauxScrollFrame_Update(scrollFrame, numAddons, numRows, ADDON_BUTTON_HEIGHT)
end

-- ============================================================================
-- WINDOW
-- ============================================================================

local function GetScale()
    local cfg = addon:GetModuleConfig("addonmanager")
    return cfg and tonumber(cfg.scale) or 1
end

local function ApplyScale()
    addon.ForeverUI.SetWindowScale(AddonListFrame, GetScale())
end

local function ScaleMenuEntries()
    local entries = { { text = L["Scale"], isTitle = true } }
    for _, step in ipairs(SCALE_STEPS) do
        entries[#entries + 1] = {
            text = math.floor(step * 100 + 0.5) .. "%",
            keepShown = true,
            checked = function() return math.abs(GetScale() - step) < 0.001 end,
            func = function()
                local cfg = addon:GetModuleConfig("addonmanager")
                if cfg then cfg.scale = step end
                ApplyScale()
            end,
        }
    end
    return entries
end

local function CreateSettingsCog(anchor)
    local cog = CreateFrame("Button", nil, AddonListFrame)
    cog:SetSize(20, 20)
    cog:SetPoint("LEFT", anchor, "RIGHT", 6, 0)
    -- The same gear as the character panel's.
    for _, layer in ipairs({ "ARTWORK", "HIGHLIGHT" }) do
        local tex = cog:CreateTexture(nil, layer)
        tex:SetAtlasTexture("questlog-icon-setting", true)
        tex:SetPoint("CENTER", cog, "CENTER", 0, 0)
        if layer == "HIGHLIGHT" then
            tex:SetAlpha(0.4)
            tex:SetBlendMode("ADD")
        end
    end
    cog:SetScript("OnClick", function(self) addon.Menu.Open(self, ScaleMenuEntries(), { clickAway = true }) end)
    cog:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(L["Panel settings"], 1, 1, 1)
        GameTooltip:Show()
    end)
    cog:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return cog
end

local function BuildWindow()
    local FUI = addon.ForeverUI
    AddonListFrame = FUI.CreateWindow("DragonUI_AddonList", UIParent, {
        width    = WINDOW_WIDTH,
        height   = WINDOW_HEIGHT,
        title    = L["Addon Manager"],
        strata   = "DIALOG",
        movable  = true,
        escClose = true,
        closable = true,
        inset    = false,
    })
    AddonListFrame:SetPoint("CENTER")
    FUI.SetResizeBounds(AddonListFrame, WINDOW_MIN_WIDTH, WINDOW_MIN_HEIGHT, WINDOW_MAX_WIDTH, WINDOW_MAX_HEIGHT)
    -- Alt+Z hides UIParent and fires OnHide too; only a real close should undo the changes.
    AddonListFrame:SetScript("OnHide", function(self)
        if not self:IsShown() then RestoreSnapshot() end
    end)

    outOfDateCheck = CreateFrame("CheckButton", nil, AddonListFrame, "UICheckButtonTemplate")
    outOfDateCheck:SetSize(24, 24)
    outOfDateCheck:SetPoint("TOPLEFT", AddonListFrame, "TOPLEFT", 14, -33)
    outOfDateCheck.text = outOfDateCheck:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    outOfDateCheck.text:SetPoint("LEFT", outOfDateCheck, "RIGHT", 4, 0)
    outOfDateCheck.text:SetText(L["Load out of date AddOns"])
    outOfDateCheck:SetScript("OnClick", function(self) SetCVar("checkAddonVersion", self:GetChecked() and "0" or "1") end)

    searchBox = FUI.CreateSearchBox(AddonListFrame, 160, L["Search..."])
    searchBox:SetPoint("TOPRIGHT", AddonListFrame, "TOPRIGHT", -42, -35)
    searchBox:SetScript("OnTextChanged", function(self)
        searchText = self:GetText()
        ApplyFilter()
        UpdateAddonList()
    end)
    CreateSettingsCog(searchBox)

    local InfoBar = CreateFrame("Frame", nil, AddonListFrame)
    InfoBar:SetPoint("TOPLEFT", AddonListFrame, "TOPLEFT", 16, -65)
    InfoBar:SetPoint("TOPRIGHT", AddonListFrame, "TOPRIGHT", -16, -65)
    InfoBar:SetHeight(20)

    local memText = InfoBar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    memText:SetPoint("LEFT", 5, 0)

    local timer = 0
    local function RefreshMemory()
        timer = 0
        UpdateAddOnMemoryUsage()
        local totalMem = 0
        for i = 1, GetNumAddOns() do totalMem = totalMem + GetAddOnMemoryUsage(i) end
        memText:SetText(L["Addon Memory:"] .. string.format(" %.2f MB", totalMem / 1024))
    end

    AddonListFrame:HookScript("OnShow", RefreshMemory)
    InfoBar:SetScript("OnUpdate", function(self, elapsed)
        timer = timer + elapsed
        if timer >= 15.0 then
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
    AddonListFrame.ListContainer:SetPoint("TOPLEFT", AddonListFrame, "TOPLEFT", 16, -LIST_TOP)
    AddonListFrame.ListContainer:SetPoint("BOTTOMRIGHT", AddonListFrame, "BOTTOMRIGHT", -16, LIST_BOTTOM)
    AddonListFrame.ListContainer:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        tile = false, tileSize = 0, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 }
    })
    AddonListFrame.ListContainer:SetBackdropColor(0.05, 0.04, 0.03, 0.55)
    AddonListFrame.ListContainer:SetBackdropBorderColor(0, 0, 0, 1)

    local btnEnableAll = FUI.CreateButton(AddonListFrame, L["Enable All"], 110, 22)
    btnEnableAll:SetPoint("BOTTOMLEFT", AddonListFrame, "BOTTOMLEFT", 16, 14)
    btnEnableAll:SetScript("OnClick", function() EnableAllAddOns(); UpdateAddonList() end)

    local btnDisableAll = FUI.CreateButton(AddonListFrame, L["Disable All"], 110, 22)
    btnDisableAll:SetPoint("LEFT", btnEnableAll, "RIGHT", 5, 0)
    btnDisableAll:SetScript("OnClick", function()
        -- The settings addon is part of DragonUI, not one of the addons this button is for ruling out.
        for i = 1, GetNumAddOns() do
            local n = GetAddOnInfo(i)
            if n ~= "DragonUI" and n ~= "DragonUI_Options" then
                DisableAddOn(i)
            end
        end
        UpdateAddonList()
    end)

    local btnCancel = FUI.CreateButton(AddonListFrame, CANCEL, 80, 22)
    btnCancel:SetPoint("BOTTOMRIGHT", AddonListFrame, "BOTTOMRIGHT", -16, 14)
    btnCancel:SetScript("OnClick", function() AddonListFrame:Hide() end)

    local btnOkay = FUI.CreateButton(AddonListFrame, L["OK / Reload"], 100, 22)
    btnOkay:SetPoint("RIGHT", btnCancel, "LEFT", -5, 0)
    btnOkay:SetScript("OnClick", function() applied = true; ReloadUI() end)

    AddonListFrame.ScrollFrame = CreateFrame("ScrollFrame", "DragonUI_AddonListScrollFrame", AddonListFrame.ListContainer, "FauxScrollFrameTemplate")
    AddonListFrame.ScrollFrame:SetPoint("TOPLEFT", AddonListFrame.ListContainer, "TOPLEFT", 0, -4)
    AddonListFrame.ScrollFrame:SetPoint("BOTTOMRIGHT", AddonListFrame.ListContainer, "BOTTOMRIGHT", -26, 4)
    if FUI.SkinScrollBar then FUI.SkinScrollBar(AddonListFrame.ScrollFrame) end

    AddonListFrame.ScrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ADDON_BUTTON_HEIGHT, UpdateAddonList)
    end)

    FUI.AddResizeGrip(AddonListFrame)
    -- Fires every frame of a drag; only a change in row count needs a repaint, widths follow their anchors.
    AddonListFrame:SetScript("OnSizeChanged", function()
        if VisibleRows() ~= shownRows then UpdateAddonList() end
    end)
end

-- ============================================================================
-- SETUP
-- ============================================================================

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event)
    WatchBrokers()
    if brokerWatcher.on then self:UnregisterEvent("ADDON_LOADED") end
    if event ~= "PLAYER_LOGIN" then return end
    self:UnregisterEvent("PLAYER_LOGIN")

    if not addon:IsModuleEnabled("addonmanager") then
        self:UnregisterAllEvents()
        local ldb = brokerWatcher.on and LibStub("LibDataBroker-1.1", true)
        if ldb then ldb.UnregisterCallback(brokerWatcher, "LibDataBroker_DataObjectCreated") end
        return
    end
    if _G.GameMenuButtonAddons then return end

    local menuBtn = CreateFrame("Button", "GameMenuButtonDragonUIAddons", GameMenuFrame, "GameMenuButtonTemplate")
    -- 140 like gamemenu.lua: at the template's 144 the Forever skin looks wider than the stock buttons.
    menuBtn:SetWidth(140)
    menuBtn:SetText(ADDONS)

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
    AddonManagerModule.initialized = true
    AddonManagerModule.applied = true

    menuBtn:SetScript("OnClick", function()
        PlaySound("igMainMenuOption")
        HideUIPanel(GameMenuFrame)
        if AddonListFrame and AddonListFrame:IsShown() then return end
        if not AddonListFrame then BuildWindow() end

        TakeSnapshot()
        outOfDateCheck:SetChecked(snapshotCheckVersion == "0")
        searchText = ""
        if searchBox then searchBox:SetText("") end
        BuildHierarchy()
        ScanLiveIcons()
        ApplyFilter()
        ApplyScale()
        UpdateAddonList()

        AddonListFrame:Show()
    end)
end)
WatchBrokers()

addon:RegisterModule("addonmanager", AddonManagerModule,
    L["Addon Manager"],
    L["Enable and disable your addons in game from an AddOns button in the Esc menu"],
    { lifecyclePrefix = "AddonManager", loadOnce = true })
