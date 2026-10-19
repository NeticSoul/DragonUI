-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.
local addon = select(2, ...)
local aliases = { mounts = 'mount', pets = 'pet', titles = 'title', tabards = 'tabard', toys = 'toy', items = 'item' }

-- Kept independent of frames so reward classification and progressive chains can be checked.
local function Matches(row, query)
    local text = string.lower((row.name or '') .. ' ' .. (row.description or '') .. ' ' .. (row.reward or ''))
    local kinds = addon.achievementRewardTypes[row.id] or ''
    for word in string.gmatch(string.lower(query or ''), '%S+') do
        local kind = aliases[word] or word
        -- Type keywords are filters: "mount" in the description is not a mount reward.
        if kind == 'mount' or kind == 'pet' or kind == 'title' or kind == 'tabard' or kind == 'toy' or kind == 'item' then
            if not string.find(' ' .. kinds .. ' ', ' ' .. kind .. ' ', 1, true) then return false end
        elseif not string.find(text, word, 1, true) then
            return false
        end
    end
    return true
end
addon.AchievementSearchMatches = Matches

local function Collect()
    local rows, seen = {}, {}
    local function visit(id)
        if not id or id == 0 or seen[id] then return end
        seen[id] = true
        local actual, name, _, completed, _, _, _, description, _, icon, reward = GetAchievementInfo(id)
        if not actual or not name then return end
        rows[#rows + 1] = { id = actual, name = name, description = description, icon = icon, reward = reward, completed = completed }
        -- Category enumeration exposes the current tier. Search every tier, including locked rewards.
        visit(GetPreviousAchievement(id))
        visit(GetNextAchievement(id))
    end
    for _, category in ipairs(GetCategoryList()) do
        for index = 1, GetCategoryNumAchievements(category) do
            local id = GetAchievementInfo(category, index)
            visit(id)
        end
    end
    table.sort(rows, function(a, b)
        if a.name == b.name then return a.id < b.id end
        return a.name < b.name
    end)
    return rows
end
addon.CollectSearchAchievements = Collect

local panel, searchButton, edit, status, previous, following
local rows, results, page = {}, {}, 1
local PAGE_SIZE = 9
local function Render()
    local pages = math.max(1, math.ceil(#results / PAGE_SIZE))
    page = math.max(1, math.min(page, pages))
    status:SetText(string.format('%d results — %d / %d', #results, page, pages))
    if page > 1 then previous:Enable() else previous:Disable() end
    if page < pages then following:Enable() else following:Disable() end
    for i, button in ipairs(rows) do
        local row = results[(page - 1) * PAGE_SIZE + i]
        button.entry = row
        if row then
            button.name:SetText((row.completed and '|cff40ff40' or '|cffffffff') .. row.name .. '|r')
            local kind = addon.achievementRewardTypes[row.id]
            button.reward:SetText((kind and ('[' .. kind .. '] ') or '') .. (row.reward or ''))
            button.icon:SetTexture(row.icon)
            button:Show()
        else button:Hide() end
    end
end
local function Search()
    results, page = {}, 1
    for _, row in ipairs(Collect()) do
        if Matches(row, edit:GetText()) then results[#results + 1] = row end
    end
    Render()
end
local function Button(parent, text, width)
    return addon.ForeverUI.CreateButton(parent, text, width or 85, 22)
end
local function Install()
    if searchButton or not AchievementFrame then return end
    searchButton = Button(AchievementFrame, 'Search', 75)
    searchButton:SetPoint('TOPRIGHT', AchievementFrame, 'TOPRIGHT', -55, -32)
    panel = addon.ForeverUI.CreateInnerFrame(AchievementFrame)
    panel:SetPoint('TOPLEFT', AchievementFrame, 'TOPLEFT', 188, -76)
    panel:SetSize(555, 430)
    panel:SetFrameLevel(AchievementFrame:GetFrameLevel() + 20)
    panel:EnableMouse(true)
    local label = panel:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    label:SetPoint('TOPLEFT', 15, -13)
    label:SetText('Search names, rewards or types: mounts, pets, titles, tabards')
    edit = CreateFrame('EditBox', nil, panel, 'InputBoxTemplate')
    edit:SetSize(420, 24)
    edit:SetPoint('TOPLEFT', 20, -34)
    addon.ForeverUI.SkinEditBox(edit, { height = 24 })
    edit:SetAutoFocus(false)
    edit:SetScript('OnTextChanged', Search)
    edit:SetScript('OnEscapePressed', function(self) self:ClearFocus(); panel:Hide() end)
    edit:SetScript('OnEnterPressed', function(self) self:ClearFocus() end)
    local close = Button(panel, 'Back', 65)
    close:SetPoint('TOPRIGHT', -12, -35)
    close:SetScript('OnClick', function() panel:Hide() end)
    for i = 1, PAGE_SIZE do
        local b = CreateFrame('Button', nil, panel)
        b:SetSize(520, 35)
        b:SetPoint('TOPLEFT', 16, -65 - (i - 1) * 35)
        b:SetHighlightTexture('Interface\\QuestFrame\\UI-QuestTitleHighlight')
        b.icon = b:CreateTexture(nil, 'ARTWORK'); b.icon:SetSize(28, 28); b.icon:SetPoint('LEFT')
        b.name = b:CreateFontString(nil, 'OVERLAY', 'GameFontNormal'); b.name:SetPoint('TOPLEFT', 35, -1); b.name:SetWidth(480); b.name:SetJustifyH('LEFT')
        b.reward = b:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); b.reward:SetPoint('TOPLEFT', 35, -18); b.reward:SetWidth(480); b.reward:SetJustifyH('LEFT')
        b:SetScript('OnClick', function(self)
            if not self.entry then return end
            panel:Hide()
            AchievementFrame_SelectAchievement(self.entry.id)
        end)
        b:SetScript('OnEnter', function(self)
            if not self.entry then return end
            GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
            GameTooltip:SetText(self.entry.name)
            GameTooltip:AddLine(self.entry.description or '', 1, 1, 1, true)
            GameTooltip:AddLine(self.entry.reward or '', 1, 0.82, 0, true)
            GameTooltip:Show()
        end)
        b:SetScript('OnLeave', function() GameTooltip:Hide() end)
        rows[i] = b
    end
    status = panel:CreateFontString(nil, 'OVERLAY', 'GameFontHighlightSmall'); status:SetPoint('BOTTOM', 0, 19)
    previous = Button(panel, 'Previous'); previous:SetPoint('BOTTOMLEFT', 15, 12)
    following = Button(panel, 'Next'); following:SetPoint('BOTTOMRIGHT', -15, 12)
    previous:SetScript('OnClick', function() page = page - 1; Render() end)
    following:SetScript('OnClick', function() page = page + 1; Render() end)
    panel:SetScript('OnShow', Search)
    AchievementFrame:HookScript('OnHide', function() panel:Hide() end)
    searchButton:SetScript('OnClick', function()
        if panel:IsShown() then panel:Hide() else panel:Show(); edit:SetFocus() end
    end)
    panel:Hide()
end
local events = CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('ACHIEVEMENT_EARNED')
events:SetScript('OnEvent', function(_, event)
    if event == 'ADDON_LOADED' then Install()
    elseif panel and panel:IsShown() then Search() end
end)
Install()
