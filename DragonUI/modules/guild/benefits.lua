-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local GU = addon.Guild
local L = GU.L

-- Guild Benefits pane, retail's perks and rewards side by side. Perks are GuildLevels' list: the
-- guild's in colour, the rest dimmed with the level they come at. Rewards are listed when the
-- server sends them (GuildLevels.rewards: { name, icon, level, requirement, cost, item, earned });
-- until then the pane says there are none.

local ROW_H = 46

local pane, perkInset, perkScroll, rewardInset, rewardScroll, rewardEmpty, noLevels
local perkRows, rewardRows = {}, {}

local function makeRow(parent, rows, i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H - 4)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -30 - (i - 1) * ROW_H)
    row:SetPoint("RIGHT", parent, "RIGHT", -24, 0)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetTexture(0, 0, 0, 0.3)
    row:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    row:GetHighlightTexture():SetBlendMode("ADD")
    row:GetHighlightTexture():SetAlpha(0.25)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(34, 34)
    row.icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.frame = row:CreateTexture(nil, "OVERLAY")
    row.frame:SetPoint("TOPLEFT", row.icon, "TOPLEFT", -2, 2)
    row.frame:SetPoint("BOTTOMRIGHT", row.icon, "BOTTOMRIGHT", 2, -2)
    row.frame:SetTexture(GU.DIR .. "Collections\\IconFrameGold")

    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
    row.name:SetPoint("RIGHT", row, "RIGHT", -70, 0)
    row.name:SetJustifyH("LEFT")

    row.level = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.level:SetPoint("TOPRIGHT", row, "TOPRIGHT", -6, -4)
    row.level:SetJustifyH("RIGHT")

    row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.text:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -2)
    row.text:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    row.text:SetHeight(14)
    row.text:SetJustifyH("LEFT")

    row:SetScript("OnEnter", function(self)
        local data = self.data
        if not data then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if data.item then
            GameTooltip:SetHyperlink("item:" .. data.item)
        else
            GameTooltip:SetText(data.name, 1, 0.82, 0)
            if data.description then GameTooltip:AddLine(data.description, 1, 1, 1, true) end
        end
        if data.requirement then GameTooltip:AddLine(data.requirement, 1, 0.1, 0.1, true) end
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", GameTooltip_Hide)
    rows[i] = row
    return row
end

local function paint(row, data, earned)
    row.data = data
    row.icon:SetDesaturated(not earned)
    row.icon:SetAlpha(earned and 1 or 0.6)
    row.frame:SetDesaturated(not earned)
    if earned then
        row.name:SetTextColor(1, 0.82, 0)
        row.text:SetTextColor(1, 1, 1)
        row.level:SetTextColor(0.25, 1, 0.25)
    else
        row.name:SetTextColor(0.6, 0.6, 0.6)
        row.text:SetTextColor(0.5, 0.5, 0.5)
        row.level:SetTextColor(0.6, 0.6, 0.6)
    end
end

local function refreshList(inset, scroll, rows, list, fill)
    local count = math.max(1, math.floor((inset:GetHeight() - 36) / ROW_H))
    FauxScrollFrame_Update(scroll, #list, count, ROW_H)
    local offset = FauxScrollFrame_GetOffset(scroll)
    for i = 1, count do
        local row, data = makeRow(inset, rows, i), list[offset + i]
        if data then
            fill(row, data)
            row:Show()
        else
            row.data = nil
            row:Hide()
        end
    end
    for i = count + 1, #rows do rows[i]:Hide() end
end

local function refresh()
    if not (pane and pane:IsShown()) then return end
    local gl = GU.Levels()
    noLevels:SetShownCompat(gl == nil)
    perkInset:SetShownCompat(gl ~= nil)
    rewardInset:SetShownCompat(gl ~= nil)
    if not gl then return end

    refreshList(perkInset, perkScroll, perkRows, gl.perks or {}, function(row, perk)
        local earned = gl.level >= perk.level
        row.icon:SetTexture("Interface\\Icons\\" .. ((gl.ICONS and gl.ICONS[perk.level]) or "INV_Misc_QuestionMark"))
        row.name:SetText(perk.name)
        row.text:SetText(perk.description)
        row.level:SetText(earned and L("Unlocked") or format(L("Level %d"), perk.level))
        paint(row, { name = perk.name, description = perk.description }, earned)
    end)

    local rewards = gl.rewards or {}
    rewardEmpty:SetShownCompat(#rewards == 0)
    refreshList(rewardInset, rewardScroll, rewardRows, rewards, function(row, reward)
        row.icon:SetTexture(reward.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        row.name:SetText(reward.name or "")
        row.text:SetText(reward.cost and (gl.Money and gl.Money(reward.cost) or GU.Number(reward.cost)) or "")
        row.level:SetText(reward.level and format(L("Level %d"), reward.level) or "")
        paint(row, reward, reward.earned)
    end)
end

local function list(name, heading)
    local inset = GU.BuildInset("DragonUIGuild" .. name .. "Inset", pane)
    local title = GU.Heading(inset, heading)
    title:SetPoint("TOPLEFT", inset, "TOPLEFT", 10, -10)
    local scroll = CreateFrame("ScrollFrame", "DragonUIGuild" .. name .. "Scroll", inset, "FauxScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", inset, "TOPLEFT", 0, -30)
    scroll:SetPoint("BOTTOMRIGHT", inset, "BOTTOMRIGHT", -24, 6)
    scroll:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_H, refresh)
    end)
    GU.SkinScroll(scroll, inset)
    return inset, scroll
end

local function build(frame)
    pane = frame
    perkInset, perkScroll = list("Perks", L("Guild Perks"))
    perkInset:SetPoint("TOPLEFT", pane, "TOPLEFT", 0, 0)
    perkInset:SetPoint("BOTTOMRIGHT", pane, "BOTTOM", -5, 0)

    rewardInset, rewardScroll = list("Rewards", L("Guild Rewards"))
    rewardInset:SetPoint("TOPLEFT", pane, "TOP", 5, 0)
    rewardInset:SetPoint("BOTTOMRIGHT", pane, "BOTTOMRIGHT", 0, 0)

    rewardEmpty = rewardInset:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    rewardEmpty:SetPoint("CENTER", rewardInset, "CENTER", 0, 0)
    rewardEmpty:SetWidth(220)
    rewardEmpty:SetText(L("This realm has no guild rewards yet."))

    noLevels = pane:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    noLevels:SetPoint("CENTER", pane, "CENTER", 0, 0)
    noLevels:SetWidth(360)
    noLevels:SetText(L("Guild perks need guild levels on the realm and the GuildLevels addon."))
end

GU.RegisterPane({
    key = "benefits", label = L("Perks & Rewards"), icon = "Achievement_Reputation_01",
    build = build, refresh = refresh,
    shown = function() GU.RequestLevels("STATE") end,
})
