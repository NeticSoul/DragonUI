local addon = select(2, ...)
local CP = addon.CharacterPanel

-- The Currency tab, rendered by us instead of Blizzard's TokenFrame, on the Reputation scaffold.
-- Backpack tracking gets its own column here rather than Blizzard's invisible modified-click popup.

local ROW_H = 24
local ICON_SIZE = 16
local CHECK_SIZE = 16
local NAME_INDENT = 10
-- How faint the tick is on a currency that is not tracked. Visible enough to read as a control
-- rather than as blank space, faint enough not to compete with the ones that are on.
local CHECK_OFF_ALPHA = 0.15
local CHECK_HOVER_ALPHA = 0.5
-- Room at the foot of the pane for Blizzard's money readout, which is 13 tall.
local MONEY_H = 20
local MONEY_RIGHT_PAD = 5

local ARENA_ICON = "Interface\\PVPFrame\\PVP-ArenaPoints-Icon"

local pane, scroll, content

-- Retail filters by categories Wrath has no concept of. SetCurrencyUnused DOES exist here, but this
-- pane offers no way to mark anything, so hiding what you hold none of is the filter that is usable.
local filterButton

local function hideEmpty() return CP:Config().currency_hide_empty and true or false end

local function updateSelection()
    if filterButton then
        filterButton:SetSelection(hideEmpty() and addon.L["Hide empty"] or addon.L["All"])
    end
end

local function filterMenuEntries()
    local function entry(text, wanted)
        return {
            text = text,
            checked = hideEmpty() == wanted,
            func = function()
                CP:Config().currency_hide_empty = wanted
                updateSelection()
                if CP.RefreshCurrencyPane then CP.RefreshCurrencyPane() end
            end,
        }
    end
    return { entry(addon.L["All"], false), entry(addon.L["Hide empty"], true) }
end
local headers, entries
local flat = {}
-- Declared here because toggleHeader hands it to the reveal driver, and it is defined further down.
local repaint

local function toggleHeader(index, collapsed)
    if collapsed then
        if ExpandCurrencyList then ExpandCurrencyList(index, 1) end
        CP.RefreshCurrencyPane()
        -- After the refresh, so the run being revealed is read off the rebuilt list.
        CP.RevealChildrenOf(flat, index, repaint)
    else
        -- The rows are still live here; collapsing for real is what `finish` does.
        CP.FadeOutChildrenOf(flat, index, repaint, function()
            if ExpandCurrencyList then ExpandCurrencyList(index, 0) end
            CP.RefreshCurrencyPane()
        end)
    end
end

-- Arena and honor points carry no icon of their own in the list; Blizzard substitutes these two.
local function applyIcon(tex, extraCurrencyType, icon)
    if extraCurrencyType == 1 then
        tex:SetTexture(ARENA_ICON)
        tex:SetTexCoord(0, 1, 0, 1)
    elseif extraCurrencyType == 2 then
        local faction = UnitFactionGroup("player")
        if faction then
            tex:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
            tex:SetTexCoord(0.03125, 0.59375, 0.03125, 0.59375)
        else
            tex:SetTexture("")
        end
    else
        tex:SetTexture(icon or "")
        tex:SetTexCoord(0, 1, 0, 1)
    end
end

local function setWatched(index, watched)
    if not SetCurrencyBackpack then return end
    if watched and GetNumWatchedTokens and MAX_WATCHED_TOKENS
        and GetNumWatchedTokens() >= MAX_WATCHED_TOKENS then
        UIErrorsFrame:AddMessage(format(TOO_MANY_WATCHED_TOKENS, MAX_WATCHED_TOKENS), 1, 0.1, 0.1, 1)
        return
    end
    PlaySound(watched and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
    SetCurrencyBackpack(index, watched and 1 or 0)
    if BackpackTokenFrame_Update then BackpackTokenFrame_Update() end
    if ManageBackpackTokenFrame then ManageBackpackTokenFrame() end
    CP.RefreshCurrencyPane()
end

local function buildEntry(parent)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(ROW_H)

    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", NAME_INDENT, 0)
    row.Icon = icon

    local check = CreateFrame("Button", nil, row)
    check:SetSize(CHECK_SIZE + 6, ROW_H)
    check:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    local tick = check:CreateTexture(nil, "OVERLAY")
    tick:set_atlas("common-icon-checkmark")
    tick:SetSize(CHECK_SIZE, CHECK_SIZE)
    tick:SetPoint("CENTER", check, "CENTER", 0, 0)
    check.Tick = tick
    check:SetScript("OnClick", function(self)
        if self._index then setWatched(self._index, not self._watched) end
    end)
    check:SetScript("OnEnter", function(self)
        if not self._watched then self.Tick:SetAlpha(CHECK_HOVER_ALPHA) end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(TOKEN_SHOW_ON_BACKPACK, nil, nil, nil, nil, 1)
    end)
    check:SetScript("OnLeave", function(self)
        if not self._watched then self.Tick:SetAlpha(CHECK_OFF_ALPHA) end
        GameTooltip:Hide()
    end)
    row.Check = check

    local count = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    count:SetPoint("RIGHT", check, "LEFT", -6, 0)
    count:SetJustifyH("RIGHT")
    row.Count = count

    local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    -- Bounded by the count so a long currency name truncates instead of running under it.
    name:SetPoint("RIGHT", count, "LEFT", -8, 0)
    name:SetJustifyH("LEFT")
    row.Text = name

    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(1, 1, 1)
    hl:SetAlpha(0.1)
    hl:SetAllPoints(row)

    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", function(self)
        if IsModifiedClick("CHATLINK") and self._itemID then
            local link = select(2, GetItemInfo(self._itemID))
            if link then ChatEdit_InsertLink(link) end
        end
    end)
    row:SetScript("OnEnter", function(self)
        if not self._index then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetCurrencyToken(self._index)
        GameTooltip:Show()
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    return row
end

local function updateEntry(row, info)
    row._index, row._itemID = info.index, info.itemID
    row.Text:SetText(info.name or "")
    row.Count:SetText(info.count or 0)
    applyIcon(row.Icon, info.extraCurrencyType, info.icon)

    -- Blizzard greys a currency the player holds none of, which is the only cue that an entry is
    -- a placeholder rather than something earned.
    local font = ((info.count or 0) == 0) and "GameFontDisable" or "GameFontHighlight"
    row.Text:SetFontObject(font)
    row.Count:SetFontObject(font)
    row.Text:SetJustifyH("LEFT")
    row.Count:SetJustifyH("RIGHT")

    local check = row.Check
    check._index, check._watched = info.index, info.isWatched
    check.Tick:SetAlpha(info.isWatched and 1 or CHECK_OFF_ALPHA)
end

repaint = function()
    if not (scroll and content) then return end
    CP.PaintListRows(scroll, content, flat, ROW_H, { headers, entries }, function(data)
        if data.kind == "header" then
            local row = headers:acquire()
            CP.UpdateListHeader(row, data.name, data.index, data.isCollapsed)
            return row, 0
        end
        local row = entries:acquire()
        updateEntry(row, data)
        return row, 0
    end)
end

local function refresh()
    if not pane or not pane:IsShown() then return end

    flat = {}
    for i = 1, (GetCurrencyListSize and GetCurrencyListSize() or 0) do
        local name, isHeader, isExpanded, _, isWatched, count,
              extraCurrencyType, icon, itemID = GetCurrencyListInfo(i)
        -- Headers always stay: dropping one strands its currencies with no way to expand back.
        local hidden = hideEmpty() and not isHeader and (count or 0) <= 0
        if name and name ~= "" and not hidden then
            flat[#flat + 1] = {
                kind = isHeader and "header" or "entry",
                index = i, name = name, isCollapsed = not isExpanded,
                isWatched = isWatched, count = count, itemID = itemID,
                extraCurrencyType = extraCurrencyType, icon = icon,
            }
        end
    end
    repaint()
end

CP.RefreshCurrencyPane = refresh

-- Blizzard's money readout is the only thing on this tab no other tab reports, so it is re-homed
-- rather than swept. Reparented, because a child of TokenFrame would sit under our pane.
local function adoptMoneyFrame(host)
    local money = _G.TokenFrameMoneyFrame
    if not money then return end
    money:SetParent(host)
    money:ClearAllPoints()
    -- Overhangs the pane on purpose: SmallMoneyFrameTemplate parks its copper coin 13px inside its
    -- own right edge, so anchoring flush would leave the coins floating well short of the rows.
    money:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", MONEY_RIGHT_PAD, 5)
    money:Show()
    if addon.RegisterBlizzardMoneyFrame then addon.RegisterBlizzardMoneyFrame(money) end
end

-- Same treatment the other two list tabs give their Blizzard frame. The popup goes with it: the
-- backpack flag it existed to set has its own column here.
local function suppressBlizzard(frame)
    if not frame or frame._duiSuppressed then return end
    frame._duiSuppressed = true

    for _, child in ipairs({ frame:GetChildren() }) do
        if child ~= _G.TokenFrameMoneyFrame then
            child:Hide()
            child.Show = child.Hide
        end
    end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "FontString" then
            region:Hide()
            region.Show = region.Hide
        end
    end
end

local function build()
    local cf = _G.CharacterFrame
    -- Blizzard_TokenUI is load-on-demand, so this builder is a no-op until the player first opens
    -- the tab; core.lua re-runs the builders on its ADDON_LOADED.
    if pane or not cf or not cf.Inset or not _G.TokenFrame then return end

    pane = CreateFrame("Frame", "DragonUICurrencyPane", cf.Inset)
    pane:SetAllPoints(cf.Inset)
    pane:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 5)
    pane:Hide()

    if CP.CreateFilterDropdown then
        local cf = _G.CharacterFrame
        filterButton = CP.CreateFilterDropdown(pane, "DragonUICurrencyFilter", CP.FILTER_DROPDOWN_W, filterMenuEntries)
        filterButton:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL + 20)
        CP.AnchorFilterDropdown(pane, filterButton)
        updateSelection()
    end

    scroll, content = CP.BuildListPane(pane, "DragonUICurrencyScroll", ROW_H, repaint, MONEY_H)
    headers = CP.NewRowPool(content, function(parent)
        return CP.BuildListHeader(parent, toggleHeader)
    end)
    entries = CP.NewRowPool(content, buildEntry)
    CP.PrewarmRowPools(scroll, ROW_H, { headers, entries })

    CP.WireListPaneShow(pane, refresh)
    scroll:HookScript("OnSizeChanged", repaint)

    local blizzard = _G.TokenFrame
    suppressBlizzard(blizzard)
    adoptMoneyFrame(pane)
    blizzard:HookScript("OnShow", function()
        suppressBlizzard(blizzard)
        pane:Show()
    end)
    blizzard:HookScript("OnHide", function() pane:Hide() end)
    if blizzard:IsShown() then pane:Show() end
end

CP.CurrencyPane = function() return pane end

local events = CreateFrame("Frame")
events:RegisterEvent("CURRENCY_DISPLAY_UPDATE")
events:RegisterEvent("KNOWN_CURRENCY_TYPES_UPDATE")
events:SetScript("OnEvent", refresh)

CP:RegisterBuilder("currencypane", build)
