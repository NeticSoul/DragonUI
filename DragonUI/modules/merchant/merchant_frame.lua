-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local Merchant = { initialized = false, applied = false }

-- Shared with sell_junk.lua and buyback_undo.lua, which merchant.xml loads after this file.
local parts = addon.merchantParts or {}
addon.merchantParts = parts

local function localized(key)
    local strings = addon.L
    local text = strings and strings[key]
    if type(text) ~= "string" or text == "" then
        return key
    end
    return text
end
parts.localized = localized

if addon.RegisterModule then
    addon:RegisterModule("merchant", Merchant, localized("Merchant"), localized("Retail-style vendor window chrome"), {
        lifecyclePrefix = "Merchant",
        loadOnce = true,
    })
end

local windowBuilt = false
local chrome = {}
local tabWidth, tabGlow, recessed = {}, {}, {}
local questAnswer = {}
local scanTip

local MERCHANT_ROWS = 10
local ALL_ROWS = 12
local CONTROL_LIFT = 4
local TAB_GLOW_ALPHA = 0.4

local CLASSIC_FILES = { "ui-merchant-top", "ui-merchant-bot", "ui-buyback-" }

-- Blizzard re-shows these on its own during updates.
local REAPPEARING = {
    "MerchantNameText", "MerchantRepairText",
    "MerchantFrameBottomLeftBorder", "MerchantFrameBottomRightBorder",
    "BuybackFrameTopLeft", "BuybackFrameTopRight", "BuybackFrameBotLeft", "BuybackFrameBotRight",
}

local SESSION_ANCHORS = {
    { "MerchantItem1", "TOPLEFT", "MerchantFrame", "TOPLEFT", 11, -69 },
    { "MerchantPrevPageButton", "CENTER", "MerchantFrame", "BOTTOMLEFT", 25, 96 },
    { "MerchantNextPageButton", "CENTER", "MerchantFrame", "BOTTOMLEFT", 310, 96 },
    { "MerchantMoneyFrame", "BOTTOMRIGHT", "MerchantFrame", "BOTTOMRIGHT", -6, 9 },
    { "MerchantBuyBackItem", "TOPLEFT", "MerchantItem10", "BOTTOMLEFT", 30, -53 },
}

local LIFTED = {
    "MerchantBuyBackItem", "MerchantPrevPageButton", "MerchantNextPageButton", "MerchantMoneyFrame",
    "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton",
    "DragonUI_MerchantSellAllJunkButton",
}
for row = 1, ALL_ROWS do
    LIFTED[#LIFTED + 1] = "MerchantItem" .. row
end

-- Texcoords on the 256x128 redbutton2x sheet: getter, left, right, top, bottom, blend.
local CLOSE_STATES = {
    { "GetNormalTexture", 0.15234375, 0.29296875, 0.0078125, 0.3046875 },
    { "GetPushedTexture", 0.15234375, 0.29296875, 0.6328125, 0.9296875 },
    { "GetDisabledTexture", 0.15234375, 0.29296875, 0.3203125, 0.6171875 },
    { "GetHighlightTexture", 0.44921875, 0.58984375, 0.0078125, 0.3046875, "ADD" },
}

-- Region suffix, width, height, anchor point, x offset, then left/right/top/bottom texcoords.
local TAB_CAPS = {
    { "Left", 35, 36, "TOPLEFT", -5, 0.015625, 0.5625, 0.816406, 0.957031 },
    { "Right", 37, 36, "TOPRIGHT", 5, 0.015625, 0.59375, 0.667969, 0.808594 },
    { "LeftDisabled", 35, 42, "TOPLEFT", -4, 0.015625, 0.5625, 0.496094, 0.660156 },
    { "RightDisabled", 37, 42, "TOPRIGHT", 6, 0.015625, 0.59375, 0.324219, 0.488281 },
}

-- Region suffix, cap suffix it spans between, height, then texcoords.
local TAB_FILLS = {
    { "Middle", "", 36, 0, 0.015625, 0.175781, 0.316406 },
    { "MiddleDisabled", "Disabled", 42, 0, 0.015625, 0.00390625, 0.167969 },
}

local REPAIR_ICON_ATLAS = {
    { "MerchantRepairAllButton", "MerchantRepairAllIcon", "spellicon-256x256-repairall" },
    { "MerchantRepairItemButton", nil, "spellicon-256x256-repair" },
    { "MerchantGuildBankRepairButton", "MerchantGuildBankRepairButtonIcon", "spellicon-256x256-repairallguild" },
}

local RECESS_OWNERS = {
    "MerchantRepairAllButton", "MerchantRepairItemButton", "MerchantGuildBankRepairButton",
    "DragonUI_MerchantSellAllJunkButton",
}

local CLUSTER_WITH_GUILD = { allX = 96, itemX = -9, sellX = 128 }
local CLUSTER_SOLO = { allX = 118, itemX = -8, sellX = 80 }

local GOLD_EDGE = { edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14 }

local function art(file)
    return addon._dir .. file
end

local function place(region, point, anchor, relativePoint, x, y)
    region:ClearAllPoints()
    region:SetPoint(point, anchor, relativePoint, x, y)
end

local function span(region, host, left, top, right, bottom)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", host, "TOPLEFT", left, top)
    region:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", right, bottom)
end

local function toggle(region, visible)
    if not region then
        return
    end
    if visible then
        region:Show()
    else
        region:Hide()
    end
end

local function lowerPath(texture)
    local file = texture and texture:GetTexture()
    if type(file) ~= "string" then
        return ""
    end
    return file:lower()
end

local function texturesOf(frame)
    local found = {}
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:GetObjectType() == "Texture" then
            found[#found + 1] = region
        end
    end
    return found
end

local function applySlices(host, layoutName)
    local slicer = _G.DragonUI_NineSlice
    if not slicer or not slicer.GetLayout or not slicer.ApplyLayout then
        return
    end
    local layout = slicer.GetLayout(layoutName)
    if layout then
        slicer.ApplyLayout(host, layout)
    end
end

local function marbleFloor(host)
    local ground = host:CreateTexture(nil, "BACKGROUND", nil, -5)
    ground:SetTexture(art("UI\\ui-background-marble"))
    ground:SetHorizTile(true)
    ground:SetVertTile(true)
    ground:SetAllPoints(host)
end

local function isClassicFile(file)
    for i = 1, #CLASSIC_FILES do
        if file:find(CLASSIC_FILES[i], 1, true) then
            return true
        end
    end
end

local function hideReappearing()
    for i = 1, #REAPPEARING do
        local region = _G[REAPPEARING[i]]
        if region then
            region:Hide()
        end
    end
end

local function stripStockArt(frame)
    local portrait = _G.MerchantFramePortrait
    for _, tex in ipairs(texturesOf(frame)) do
        if tex ~= portrait and tex ~= chrome.streaks then
            local layer = tex:GetDrawLayer()
            local stock = layer == "BACKGROUND"
                or ((layer == "BORDER" or layer == "ARTWORK") and isClassicFile(lowerPath(tex)))
            if stock then
                tex:Hide()
            end
        end
    end
end

local function shapeWindow(frame)
    frame:SetSize(336, 444)
    frame:SetHitRectInsets(0, 0, 0, 0)
    -- Only xoffset: GetUIPanelWindowInfo copies area/pushable itself; extra writes risk UIPanel taint.
    if frame:GetAttribute("UIPanelLayout-xoffset") ~= 6 then
        frame:SetAttribute("UIPanelLayout-xoffset", 6)
        if frame:IsShown() then
            UpdateUIPanelPositions(frame)
        end
    end
end

local function anchorControls()
    for _, spec in ipairs(SESSION_ANCHORS) do
        local region, target = _G[spec[1]], _G[spec[3]]
        if region and target then
            place(region, spec[2], target, spec[4], spec[5], spec[6])
        end
    end
end

-- FontStrings have no frame level; the holder lifts the page text above the bottom band.
local function housePageText(frame)
    local holder = CreateFrame("Frame", nil, frame)
    holder:EnableMouse(false)
    holder:SetSize(104, 20)
    holder:SetPoint("BOTTOM", frame, "BOTTOM", 0, 86)
    holder:Show()
    chrome.pageHolder = holder

    local label = _G.MerchantPageText
    if label then
        label:SetParent(holder)
        place(label, "BOTTOM", holder, "BOTTOM", 0, 0)
        label:SetWidth(104)
        label:SetJustifyH("CENTER")
    end
end

local function liftControls()
    local level = _G.MerchantFrame:GetFrameLevel() + CONTROL_LIFT
    for _, name in ipairs(LIFTED) do
        local widget = _G[name]
        if widget then
            widget:SetFrameLevel(level)
        end
    end
    if chrome.pageHolder then
        chrome.pageHolder:SetFrameLevel(level)
    end
end

local function paintBody(frame)
    local rock = frame.Bg
    if not rock then
        rock = frame:CreateTexture(nil, "BACKGROUND", nil, -6)
        frame.Bg = rock
    end
    rock:SetTexture(art("UI\\ui-background-rock"))
    rock:SetTexCoord(0, 1, 0, 1)
    rock:SetHorizTile(true)
    rock:SetVertTile(true)
    rock:SetVertexColor(1, 1, 1, 1)
    span(rock, frame, 2, -21, -2, 2)
    rock:Show()
end

local function addStreaks(frame)
    local streaks = frame:CreateTexture(nil, "BORDER")
    streaks:SetAtlasTexture("_UI-Frame-TopTileStreaks", false)
    streaks:SetHorizTile(true)
    streaks:SetHeight(43)
    streaks:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -21)
    streaks:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -21)
    chrome.streaks = streaks
end

local function titleText()
    local source = _G.MerchantNameText
    return source and source:GetText() or ""
end

local function ensureTitle(frame)
    local title = frame.Title
    if not title then
        title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 60, -5)
        title:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -24, -5)
        title:SetHeight(16)
        title:SetJustifyH("CENTER")
        frame.Title = title
    end
    title:SetText(titleText())
end

-- No masks in 3.3.5a: a bigger face would spill past the nine-slice ring.
local function seatPortrait(frame)
    local face = _G.MerchantFramePortrait
    if not face then
        return
    end
    place(face, "TOPLEFT", frame, "TOPLEFT", -2, 4)
    face:SetSize(56, 56)
    face:SetDrawLayer("ARTWORK")
end

local function buildGrid(frame, level)
    local grid = CreateFrame("Frame", nil, frame)
    grid:EnableMouse(false)
    grid:SetFrameLevel(level)
    span(grid, frame, 4, -60, -6, 26)
    applySlices(grid, "InsetFrameTemplate")
    marbleFloor(grid)

    local wash = grid:CreateTexture(nil, "ARTWORK")
    wash:SetTexture(1, 1, 1)
    wash:SetAlpha(0.2)
    wash:SetAllPoints(grid)
    wash:Hide()
    chrome.wash = wash
end

local function buildBand(frame, level)
    local band = CreateFrame("Frame", nil, frame)
    band:SetFrameLevel(level)
    band:SetHeight(61)
    band:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 26)
    band:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 26)

    local plate = band:CreateTexture(nil, "ARTWORK")
    plate:SetAtlasTexture("ui-merchant-botframe", false)
    plate:SetAllPoints(band)
    chrome.band = band
end

local function buildPurse(frame, level)
    local purse = CreateFrame("Frame", nil, frame)
    purse:EnableMouse(false)
    purse:SetFrameLevel(level)
    purse:SetPoint("TOPLEFT", frame, "BOTTOMRIGHT", -171, 36)
    purse:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -5, 4)
    applySlices(purse, "InsetFrameTemplate")
    marbleFloor(purse)

    local rim = CreateFrame("Frame", nil, purse)
    rim:EnableMouse(false)
    rim:SetFrameLevel(purse:GetFrameLevel() + 1)
    rim:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", -7, 25)
    rim:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", -166, 6)
    rim:SetBackdrop(GOLD_EDGE)
    rim:SetBackdropBorderColor(1, 0.82, 0.32, 1)
end

local function findCloseButton(frame)
    local known = frame.CloseButton or _G.MerchantFrameCloseButton
    if known then
        return known
    end
    for _, child in ipairs({ frame:GetChildren() }) do
        if child:IsObjectType("Button") and lowerPath(child:GetNormalTexture()):find("ui-panel-minimizebutton", 1, true) then
            return child
        end
    end
end

local function styleCloseButton(frame)
    local button = findCloseButton(frame)
    if not button then
        return
    end
    frame.CloseButton = button
    button:SetSize(24, 24)
    place(button, "TOPRIGHT", frame, "TOPRIGHT", 1, 0)
    button:SetFrameLevel(frame:GetFrameLevel() + 20)

    local sheet = art("UI\\redbutton2x")
    for _, look in ipairs(CLOSE_STATES) do
        local tex = button[look[1]](button)
        if tex then
            tex:SetTexture(sheet)
            tex:SetTexCoord(look[2], look[3], look[4], look[5])
            if look[6] then
                tex:SetBlendMode(look[6])
            end
        end
    end
end

local function dressPager(button, direction)
    if not button then
        return
    end
    local backing = art("Merchant\\pagebutton-background")
    for _, tex in ipairs(texturesOf(button)) do
        if tex:GetDrawLayer() == "BACKGROUND" then
            tex:SetTexture(backing)
            tex:Show()
        end
    end

    local stem = "Merchant\\pagebutton-" .. direction .. "-"
    button:SetNormalTexture(art(stem .. "normal"))
    button:SetPushedTexture(art(stem .. "pressed"))
    button:SetDisabledTexture(art(stem .. "disabled"))
    button:SetHighlightTexture(art("Merchant\\pagebutton-hover"))
    local hover = button:GetHighlightTexture()
    if hover then
        hover:SetBlendMode("ADD")
    end
end

local function addQuestBang(button)
    local bang = button:CreateTexture(nil, "OVERLAY")
    bang:SetTexture(_G.TEXTURE_ITEM_QUEST_BANG or "Interface\\ContainerFrame\\QuestBang")
    bang:SetSize(37, 38)
    bang:SetPoint("TOP", button, "TOP", 0, 0)
    bang:Hide()
    button.IconQuestTexture = bang
end

local function reskinRow(prefix, isBuybackRow)
    local recess = _G[prefix .. "SlotTexture"]
    if recess then
        recess:SetTexture(art("Merchant\\emptyslot"))
    end

    local button = _G[prefix .. "ItemButton"]
    local ring = button and button:GetNormalTexture()
    if ring then
        ring:SetTexture(art("UI\\ui-quickslot2"))
        ring:SetSize(64, 64)
        place(ring, "CENTER", button, "CENTER", 0, -1)
    end

    local plate = _G[prefix .. "NameFrame"]
    if plate and isBuybackRow then
        plate:Hide()
    elseif plate then
        plate:SetTexture(art("Merchant\\labelslots"))
        plate:SetVertexColor(0.5, 0.5, 0.5, 1)
        plate:Show()
    end

    if button and not isBuybackRow and not button.IconQuestTexture then
        addQuestBang(button)
    end
end

local function questScanner()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "DragonUI_MerchantQuestScan", UIParent, "GameTooltipTemplate")
    end
    -- A GameTooltip loses its owner whenever it hides and then reports no lines.
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    return scanTip
end

local function beginsQuest(link)
    local itemID = link and tonumber(link:match("item:(%d+)"))
    if not itemID then return false end
    if questAnswer[itemID] ~= nil then
        return questAnswer[itemID]
    end

    local tip = questScanner()
    tip:ClearLines()
    tip:SetHyperlink(link)
    local lineCount = tip:NumLines()
    local verdict = false
    for line = 2, lineCount do
        local left = _G["DragonUI_MerchantQuestScanTextLeft" .. line]
        if left and left:GetText() == ITEM_STARTS_QUEST then
            verdict = true
            break
        end
    end
    -- An uncached item answers with a one-line tooltip: that is "unknown", not "no".
    if verdict or lineCount > 1 then
        questAnswer[itemID] = verdict
    end
    return verdict
end

local function nameColour(link)
    if link then
        local quality = select(3, GetItemInfo(link))
        if quality ~= nil then
            local swatch = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
            if swatch then
                return swatch.r, swatch.g, swatch.b
            end
        else
            -- Uncached items have no quality yet, but the link already carries their colour.
            local r, g, b = link:match("^|c%x%x(%x%x)(%x%x)(%x%x)")
            if r then
                return tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255
            end
        end
    end
    local plain = NORMAL_FONT_COLOR
    return plain.r, plain.g, plain.b
end

local function tintName(label, link)
    if label then
        label:SetTextColor(nameColour(link))
    end
end

local function spaceRows(gap)
    for index = 3, 9, 2 do
        local row, above = _G["MerchantItem" .. index], _G["MerchantItem" .. (index - 2)]
        if not row or not above then
            return
        end
        row:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, gap)
    end
    local lastRow, above = _G.MerchantItem11, _G.MerchantItem9
    if lastRow and above then
        place(lastRow, "TOPLEFT", above, "BOTTOMLEFT", 0, gap)
    end
end

local function afterMerchantInfo()
    spaceRows(-8)
    local perPage = MERCHANT_ITEMS_PER_PAGE or 10
    local offset = ((_G.MerchantFrame.page or 1) - 1) * perPage
    for row = 1, MERCHANT_ROWS do
        local link = GetMerchantItemLink(offset + row)
        tintName(_G["MerchantItem" .. row .. "Name"], link)
        local button = _G["MerchantItem" .. row .. "ItemButton"]
        local bang = button and button.IconQuestTexture
        toggle(bang, bang ~= nil and beginsQuest(link))
    end

    local stored = GetNumBuybackItems() or 0
    tintName(_G.MerchantBuyBackItemName, stored > 0 and GetBuybackItemLink(stored) or nil)
end

local function afterBuybackInfo()
    spaceRows(-15)
    for row = 1, BUYBACK_ITEMS_PER_PAGE or ALL_ROWS do
        tintName(_G["MerchantItem" .. row .. "Name"], GetBuybackItemLink(row))
        local button = _G["MerchantItem" .. row .. "ItemButton"]
        if button and button.IconQuestTexture then
            button.IconQuestTexture:Hide()
        end
    end
end

local function clampLabel(label, width)
    if not label then
        return
    end
    label:SetWordWrap(false)
    if label.SetMaxLines then
        label:SetMaxLines(1)
    end
    label:SetWidth(width)
end

local function clampNames()
    for row = 1, ALL_ROWS do
        clampLabel(_G["MerchantItem" .. row .. "Name"], 84)
    end
    -- The buyback row sits 30px further right, so its name gets less room.
    clampLabel(_G.MerchantBuyBackItemName, 74)
end

local function glowPiece(tab, sheet, left, right, top, bottom)
    local glow = tab:CreateTexture(nil, "HIGHLIGHT")
    glow:SetTexture(sheet)
    glow:SetTexCoord(left, right, top, bottom)
    glow:SetBlendMode("ADD")
    glow:SetAlpha(TAB_GLOW_ALPHA)
    glow:SetHeight(30)
    return glow
end

local function addTabGlow(tab, sheet, leftCap, rightCap)
    local west = glowPiece(tab, sheet, 0.015625, 0.5625, 0.816406, 0.933594)
    west:SetWidth(35)
    west:SetPoint("TOPLEFT", leftCap, "TOPLEFT", 0, 0)

    local east = glowPiece(tab, sheet, 0.015625, 0.59375, 0.667969, 0.785156)
    east:SetWidth(37)
    east:SetPoint("TOPLEFT", rightCap, "TOPLEFT", 0, 0)

    local between = glowPiece(tab, sheet, 0, 0.015625, 0.175781, 0.292969)
    between:SetPoint("TOPLEFT", west, "TOPRIGHT", 0, 0)
    between:SetPoint("TOPRIGHT", east, "TOPLEFT", 0, 0)

    tabGlow[tab] = { west, between, east }
end

local function dressTab(tab)
    local name = tab:GetName()
    local sheet = art("UI\\uiframetabs")
    tab:SetFrameLevel(tab:GetFrameLevel() + CONTROL_LIFT)
    tab:SetNormalFontObject(GameFontNormalSmall)
    tab:SetHighlightFontObject(GameFontHighlightSmall)

    for _, cap in ipairs(TAB_CAPS) do
        local tex = _G[name .. cap[1]]
        if tex then
            tex:SetTexture(sheet)
            tex:SetTexCoord(cap[6], cap[7], cap[8], cap[9])
            tex:SetSize(cap[2], cap[3])
            place(tex, cap[4], tab, cap[4], cap[5], 0)
        end
    end

    for _, fill in ipairs(TAB_FILLS) do
        local tex = _G[name .. fill[1]]
        local leftCap, rightCap = _G[name .. "Left" .. fill[2]], _G[name .. "Right" .. fill[2]]
        if tex and leftCap and rightCap then
            tex:SetTexture(sheet)
            tex:SetTexCoord(fill[4], fill[5], fill[6], fill[7])
            tex:SetSize(1, fill[3])
            tex:ClearAllPoints()
            tex:SetPoint("TOPLEFT", leftCap, "TOPRIGHT", 0, 0)
            tex:SetPoint("TOPRIGHT", rightCap, "TOPLEFT", 0, 0)
        end
    end

    local stock = tab:GetHighlightTexture()
    if stock then
        stock:SetTexture(nil)
    end
    local leftCap, rightCap = _G[name .. "Left"], _G[name .. "Right"]
    if leftCap and rightCap then
        addTabGlow(tab, sheet, leftCap, rightCap)
    end

    local label = _G[name .. "Text"]
    local textWidth = label and label:GetStringWidth() or 0
    tabWidth[tab] = math.max(64, textWidth + 24)
    tab:SetWidth(tabWidth[tab])
end

local function chainTabs(frame)
    local previous
    for index = 1, 2 do
        local tab = _G["MerchantFrameTab" .. index]
        if tab and tab:IsShown() then
            if previous then
                place(tab, "TOPLEFT", previous, "TOPRIGHT", 1, 0)
            else
                place(tab, "TOPLEFT", frame, "BOTTOMLEFT", 11, 2)
            end
            previous = tab
        end
    end
end

local function syncTabs(selected)
    for index = 1, 2 do
        local tab = _G["MerchantFrameTab" .. index]
        if tab then
            local active = index == selected
            tab:SetNormalFontObject(GameFontNormalSmall)
            tab:SetHighlightFontObject(GameFontHighlightSmall)
            -- Blizzard draws the selected tab in its disabled state.
            tab:SetDisabledFontObject(active and GameFontHighlightSmall or GameFontNormalSmall)
            if tabWidth[tab] then
                tab:SetWidth(tabWidth[tab])
            end
            local label = _G[tab:GetName() .. "Text"]
            if label then
                place(label, "CENTER", tab, "CENTER", -2, active and -7 or 0)
            end
            local glows = tabGlow[tab]
            if glows then
                for _, glow in ipairs(glows) do
                    glow:SetAlpha(active and 0 or TAB_GLOW_ALPHA)
                end
            end
        end
    end
end

local function fitRepairIcons()
    for _, entry in ipairs(REPAIR_ICON_ATLAS) do
        local button = _G[entry[1]]
        local icon = entry[2] and _G[entry[2]]
        if button and not icon then
            for _, tex in ipairs(texturesOf(button)) do
                if lowerPath(tex):find("ui-merchant-repairicons", 1, true) then
                    icon = tex
                    break
                end
            end
        end
        if button and icon then
            icon:SetAtlasTexture(entry[3], false)
            span(icon, button, 0, 0, 0, 0)
        end
    end
end

local function sinkButtons()
    local pitFile = art("Merchant\\emptyslot")
    for _, name in ipairs(RECESS_OWNERS) do
        local button = _G[name]
        if button and not recessed[button] then
            local pit = button:CreateTexture(nil, "BACKGROUND")
            pit:SetTexture(pitFile)
            pit:SetSize(64, 64)
            pit:SetPoint("TOPLEFT", button, "TOPLEFT", -13, 14)
            recessed[button] = pit
        end
    end
end

-- Blizzard re-anchors these every update and shrinks two to 32 when guild repair is available.
local function arrangeRepairCluster()
    -- This updater also runs alone (GUILDBANK_UPDATE_MONEY, PLAYER_MONEY) and re-shows the label.
    toggle(_G.MerchantRepairText, false)
    local window = _G.MerchantFrame
    if not window or window.selectedTab ~= 1 then
        return
    end
    local junkButton = _G.DragonUI_MerchantSellAllJunkButton
    local repairAll = _G.MerchantRepairAllButton

    if not _G.CanMerchantRepair() or not repairAll then
        if junkButton then
            place(junkButton, "BOTTOMRIGHT", window, "BOTTOMRIGHT", -148, 33)
        end
        return
    end

    local guildToo = CanGuildBankRepair()
    local spots = guildToo and CLUSTER_WITH_GUILD or CLUSTER_SOLO
    repairAll:SetSize(36, 36)
    place(repairAll, "BOTTOMRIGHT", window, "BOTTOMLEFT", spots.allX, 33)

    local repairItem = _G.MerchantRepairItemButton
    if repairItem then
        repairItem:SetSize(36, 36)
        place(repairItem, "RIGHT", repairAll, "LEFT", spots.itemX, 0)
    end
    local guildButton = _G.MerchantGuildBankRepairButton
    if guildToo and guildButton then
        guildButton:SetSize(36, 36)
        place(guildButton, "LEFT", repairAll, "RIGHT", 8, 0)
    end
    if junkButton then
        place(junkButton, "RIGHT", repairAll, "LEFT", spots.sellX, 0)
    end
end

local function syncWindow()
    local window = _G.MerchantFrame
    hideReappearing()
    syncTabs(window.selectedTab)
    if window.Title then
        window.Title:SetText(titleText())
    end
    local buying = window.selectedTab == 1
    toggle(chrome.wash, not buying)
    toggle(chrome.band, buying)
    toggle(_G.DragonUI_MerchantSellAllJunkButton, buying)
    clampNames()
end

local function buildWindow()
    local window = _G.MerchantFrame
    local insetLevel = window:GetFrameLevel() + 1

    applySlices(window, "PortraitFrameTemplate")
    paintBody(window)
    addStreaks(window)
    ensureTitle(window)
    seatPortrait(window)
    -- Equal-level siblings stack by creation order, which is what keeps grid < band < purse.
    buildGrid(window, insetLevel)
    buildBand(window, insetLevel)
    buildPurse(window, insetLevel)
    styleCloseButton(window)
    dressPager(_G.MerchantPrevPageButton, "prev")
    dressPager(_G.MerchantNextPageButton, "next")

    for row = 1, ALL_ROWS do
        reskinRow("MerchantItem" .. row, false)
    end
    reskinRow("MerchantBuyBackItem", true)

    for index = 1, 2 do
        local tab = _G["MerchantFrameTab" .. index]
        if tab then
            dressTab(tab)
        end
    end
    chainTabs(window)

    fitRepairIcons()
    if parts.buildSellButton then
        parts.buildSellButton()
    end
    if parts.buildUndoArrow then
        parts.buildUndoArrow()
    end
    sinkButtons()
    -- Last, so the sell button is lifted too: at +1 it tied with the band and lost the draw order.
    liftControls()
end

-- MerchantFrame registered MERCHANT_SHOW first, so the window is already shown and filled here.
local function onFirstMerchantShow(listener)
    listener:UnregisterEvent("MERCHANT_SHOW")
    listener:SetScript("OnEvent", nil)

    local ok, err = pcall(buildWindow)
    if not ok then
        addon:Error("Merchant build failed: " .. tostring(err))
        return
    end
    windowBuilt = true

    if _G.MerchantFrame:IsShown() then
        -- Retexturing the anvils dropped the grey OnShow gave them; these put it back.
        MerchantFrame_UpdateCanRepairAll()
        MerchantFrame_UpdateGuildBankRepair()
        MerchantFrame_Update()
    else
        syncWindow()
    end
end

local function prepareSession(frame)
    stripStockArt(frame)
    hideReappearing()
    shapeWindow(frame)
    anchorControls()
    housePageText(frame)
    liftControls()

    hooksecurefunc("MerchantFrame_Update", function()
        if windowBuilt then
            syncWindow()
        end
    end)
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
        if windowBuilt then
            afterMerchantInfo()
        end
    end)
    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", function()
        if windowBuilt then
            afterBuybackInfo()
        end
    end)
    hooksecurefunc("MerchantFrame_UpdateRepairButtons", arrangeRepairCluster)

    local listener = CreateFrame("Frame")
    listener:SetScript("OnEvent", onFirstMerchantShow)
    listener:RegisterEvent("MERCHANT_SHOW")
end

function addon.ApplyMerchantSystem()
    if not addon:IsModuleEnabled("merchant") then
        return
    end
    Merchant.applied = true

    local window = _G.MerchantFrame
    if Merchant.initialized or not window then
        return
    end
    Merchant.initialized = true
    prepareSession(window)
end

function addon.RestoreMerchantSystem()
    Merchant.applied = false
end

local loginWatcher = CreateFrame("Frame")
loginWatcher:RegisterEvent("PLAYER_LOGIN")
loginWatcher:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    addon.ApplyMerchantSystem()
end)
