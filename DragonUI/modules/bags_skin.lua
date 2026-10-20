-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local L = addon.L

local _G = _G
local type = type
local pairs = pairs
local BACKPACK_CONTAINER = BACKPACK_CONTAINER or 0
local KEYRING_CONTAINER = KEYRING_CONTAINER or -2
local NUM_BAG_SLOTS = NUM_BAG_SLOTS or 4
local NUM_BANKBAGSLOTS = NUM_BANKBAGSLOTS or 7
local MAX_CONTAINER_ITEMS = 36
local MAX_CONTAINER_FRAMES = 13
local BAG_VERTICAL_GAP = 4
local BAG_HORIZONTAL_GAP = 9

local assets = addon._dir
local textures = {
    slot = assets .. "Bags\\bagsitemslot2x",
    bankSlot = assets .. "Bags\\bagsitembankslot2x",
    background = assets .. "UI\\ui-background-rock",
    close = assets .. "UI\\redbutton2x",
    pushed = assets .. "UI\\ui-quickslot-depress",
    highlight = assets .. "UI\\buttonhilight-square",
    slotBorder = assets .. "UI\\ui-quickslot2",
    coinbox = assets .. "Coins\\commoncoinbox",
    currencybox = assets .. "Coins\\commoncurrencybox",
    coinGold = assets .. "Coins\\coingold",
    coinSilver = assets .. "Coins\\coinsilver",
    coinCopper = assets .. "Coins\\coincopper",
}

-- Native layout splits CONTAINER_WIDTH's 29px slack 17/12 left-right; this recenters the grid.
local ITEM_GRID_X_NUDGE = -2.5
local ITEM_GRID_Y_NUDGE = 3

-- Room the close button takes on the right, kept on the left too so the title stays centred.
local TITLE_LEFT_CLEARANCE = 24
local TITLE_RIGHT_CLEARANCE = 24

local classicBackgrounds = {
    "BackgroundTop",
    "BackgroundMiddle1",
    "BackgroundMiddle2",
    "BackgroundBottom",
    "Background1Slot",
}

local BagSkinModule = {
    applied = false,
    initialized = false,
    hooksInstalled = false,
}

if addon.RegisterModule then
    addon:RegisterModule(
        "bags_skin",
        BagSkinModule,
        L["Bag Skin"],
        L["Retail-style skin for Blizzard bag windows"],
        { loadOnce = true }
    )
end

local function IsActive()
    return BagSkinModule.applied and addon:IsModuleEnabled("bags_skin")
end

local function IsBankBag(bagID)
    return type(bagID) == "number"
        and bagID >= NUM_BAG_SLOTS + 1
        and bagID <= NUM_BAG_SLOTS + NUM_BANKBAGSLOTS
end

local function ConfigureTexture(texture, path, width, height, left, right, top, bottom)
    texture:SetTexture(path)
    texture:SetSize(width, height)
    texture:SetTexCoord(left, right, top, bottom)
end

local function EnsureChrome(frame, key)
    local chrome = frame[key]
    if chrome then
        return chrome
    end

    chrome = {
        topLeft = frame:CreateTexture(nil, "OVERLAY"),
        topRight = frame:CreateTexture(nil, "OVERLAY"),
        bottomLeft = frame:CreateTexture(nil, "OVERLAY"),
        bottomRight = frame:CreateTexture(nil, "OVERLAY"),
        top = frame:CreateTexture(nil, "OVERLAY"),
        bottom = frame:CreateTexture(nil, "OVERLAY"),
        left = frame:CreateTexture(nil, "OVERLAY"),
        right = frame:CreateTexture(nil, "OVERLAY"),
    }

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(textures.background)
    -- Retail's FlatPanelBackgroundTemplate tints this bg with PANEL_BACKGROUND_COLOR, alpha 0.8.
    background:SetAlpha(0.8)
    chrome.background = background

    frame[key] = chrome
    return chrome
end

-- The bronze chrome every window wears: pieces and offsets read from the shared layout
-- (nineslice.lua's NoPortraitFrameTemplate), scaled down for compact one-slot bags.
local function SetBronze(texture, name, scale)
    local e = addon.atlasinfo[name]
    ConfigureTexture(texture, e[1], e[2] * scale, e[3] * scale, e[4], e[5], e[6], e[7])
end

local CORNERS = {
    { "topLeft", "TopLeftCorner", "TOPLEFT" },
    { "topRight", "TopRightCorner", "TOPRIGHT" },
    { "bottomLeft", "BottomLeftCorner", "BOTTOMLEFT" },
    { "bottomRight", "BottomRightCorner", "BOTTOMRIGHT" },
}

local function LayoutChrome(frame, chrome, compact)
    local s = compact and 0.7 or 1
    local layout = DragonUI_NineSlice.GetLayout("NoPortraitFrameTemplate")

    for _, c in ipairs(CORNERS) do
        local texture, spec, point = chrome[c[1]], layout[c[2]], c[3]
        SetBronze(texture, spec.atlas, s)
        texture:ClearAllPoints()
        texture:SetPoint(point, frame, point, spec.x * s, spec.y * s)
    end

    -- Edges run flush between the corners, stretched.
    SetBronze(chrome.top, layout.TopEdge.atlas, s)
    chrome.top:ClearAllPoints()
    chrome.top:SetPoint("TOPLEFT", chrome.topLeft, "TOPRIGHT")
    chrome.top:SetPoint("TOPRIGHT", chrome.topRight, "TOPLEFT")

    SetBronze(chrome.bottom, layout.BottomEdge.atlas, s)
    chrome.bottom:ClearAllPoints()
    chrome.bottom:SetPoint("BOTTOMLEFT", chrome.bottomLeft, "BOTTOMRIGHT")
    chrome.bottom:SetPoint("BOTTOMRIGHT", chrome.bottomRight, "BOTTOMLEFT")

    SetBronze(chrome.left, layout.LeftEdge.atlas, s)
    chrome.left:ClearAllPoints()
    chrome.left:SetPoint("TOPLEFT", chrome.topLeft, "BOTTOMLEFT")
    chrome.left:SetPoint("BOTTOMLEFT", chrome.bottomLeft, "TOPLEFT")

    SetBronze(chrome.right, layout.RightEdge.atlas, s)
    chrome.right:ClearAllPoints()
    chrome.right:SetPoint("TOPRIGHT", chrome.topRight, "BOTTOMRIGHT")
    chrome.right:SetPoint("BOTTOMRIGHT", chrome.bottomRight, "TOPRIGHT")

    chrome.background:ClearAllPoints()
    chrome.background:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, compact and -14 or -20)
    chrome.background:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 3)
end

local function SkinCloseButton(button, compact)
    if not button then
        return
    end

    -- Compact bags wear the chrome at 0.7, so the seat shrinks with it.
    addon.SeatCloseButton(button, button:GetParent(), compact and 0.7 or 1)

    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexture(textures.close)
        normal:SetTexCoord(0.152344, 0.292969, 0.0078125, 0.304688)
    end

    local disabled = button:GetDisabledTexture()
    if disabled then
        disabled:SetTexture(textures.close)
        disabled:SetTexCoord(0.152344, 0.292969, 0.320312, 0.617188)
    end

    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:SetTexture(textures.close)
        pushed:SetTexCoord(0.152344, 0.292969, 0.632812, 0.929688)
    end

    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetTexture(textures.close)
        highlight:SetTexCoord(0.449219, 0.589844, 0.0078125, 0.304688)
    end
end

local function SkinItemButton(button, bankSlot)
    if not button then
        return
    end

    local normal = button:GetNormalTexture()
    if normal then
        normal:SetTexture(bankSlot and textures.bankSlot or textures.slot)
        normal:SetSize(37, 37)
        normal:ClearAllPoints()
        normal:SetPoint("CENTER", button, "CENTER")
        normal:SetDrawLayer("BACKGROUND")
        normal:Show()
    end

    -- Separate BORDER texture: no sublevel in 3.3.5a's SetDrawLayer to stack it above the flat bg.
    local border = button._dragonuiSlotBorder
    if not border then
        border = button:CreateTexture(nil, "BORDER")
        button._dragonuiSlotBorder = border
    end
    border:SetTexture(textures.slotBorder)
    border:SetSize(64, 64)
    border:ClearAllPoints()
    -- (0, -1) matches vanilla's own UI-Quickslot2 anchor, compensating the ring art's 1px asymmetry.
    border:SetPoint("CENTER", button, "CENTER", 0, -1)
    border:Show()

    local pushed = button:GetPushedTexture()
    if pushed then
        pushed:SetTexture(textures.pushed)
        pushed:SetSize(37, 37)
        pushed:ClearAllPoints()
        pushed:SetPoint("CENTER", button, "CENTER")
    end

    local highlight = button:GetHighlightTexture()
    if highlight then
        highlight:SetTexture(textures.highlight)
        highlight:SetSize(37, 37)
        highlight:ClearAllPoints()
        highlight:SetPoint("CENTER", button, "CENTER")
    end

    local name = button:GetName()
    if not name then
        return
    end

    local icon = _G[name .. "IconTexture"]
    if icon then
        -- ItemButtonTemplate ships IconTexture with no Size/Anchors; force it to fill the button.
        icon:SetDrawLayer("BORDER")
        icon:SetTexCoord(0, 1, 0, 1)
        icon:ClearAllPoints()
        icon:SetAllPoints(button)
    end

    local count = _G[name .. "Count"]
    if count then
        count:SetDrawLayer("BORDER")
    end

    local stock = _G[name .. "Stock"]
    if stock then
        stock:SetDrawLayer("BORDER")
    end
end

local function HideClassicBackgrounds(frame)
    local name = frame:GetName()
    for _, suffix in pairs(classicBackgrounds) do
        local texture = _G[name .. suffix]
        if texture then
            texture:Hide()
        end
    end
end

-- No portrait (no window carries one). Its button stays as an invisible strip over the title band,
-- so hovering the band still shows the bag's tooltip: the only label a compact bag has, as its
-- title is hidden. Blizzard re-textures the portrait on every bag open, so this runs each refresh.
local function DressContainerPortrait(frame, compact)
    local name = frame:GetName()
    local portrait = _G[name .. "Portrait"]
    local portraitButton = _G[name .. "PortraitButton"]
    if portrait then portrait:Hide() end
    if portraitButton then
        portraitButton:ClearAllPoints()
        portraitButton:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, 0)
        portraitButton:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", compact and -22 or -26, compact and -16 or -22)
        local highlight = portraitButton:GetHighlightTexture()
        if highlight then highlight:SetTexture(nil) end
        portraitButton:Show()
    end
end

local function RefreshContainerTitle(frame, compact)
    local nativeTitle = _G[frame:GetName() .. "Name"]
    local title = frame._dragonuiBagChrome.title
    if nativeTitle then
        nativeTitle:Hide()
    end

    if compact then
        title:Hide()
        return
    end

    local bagID = frame:GetID()
    if bagID == KEYRING_CONTAINER then
        title:SetText(KEYRING)
    else
        title:SetText(GetBagName(bagID) or "")
    end

    title:ClearAllPoints()
    -- TOP anchor keeps text truly centered; LEFT/RIGHT clearance boxes would skew it on our narrow frames.
    title:SetPoint("TOP", frame, "TOP", 0, -7)
    title:SetJustifyH("CENTER")
    -- Width from the clearances (not a guessed number) clips overflow instead of wrapping it.
    title:SetWidth(frame:GetWidth() - TITLE_LEFT_CLEARANCE - TITLE_RIGHT_CLEARANCE)
    title:SetWordWrap(false)
    title:Show()
end

local function PrepareContainerFrame(frame)
    if frame._dragonuiBagSkinPrepared then
        return
    end

    frame._dragonuiBagSkinPrepared = true
    local chrome = EnsureChrome(frame, "_dragonuiBagChrome")
    chrome.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    SkinCloseButton(_G[frame:GetName() .. "CloseButton"], false)

    for i = 1, MAX_CONTAINER_ITEMS do
        SkinItemButton(_G[frame:GetName() .. "Item" .. i], false)
    end

    frame:HookScript("OnShow", function(self)
        if IsActive() then
            BagSkinModule:RefreshContainerFrame(self)
        end
    end)
end

local BOTTOM_PILL_HEIGHT = 17
local BOTTOM_PILL_GAP = 3
-- Blizzard re-anchors the coins on every update, so the frame rises and its pill sinks by the same amount.
local MONEY_LIFT = 0.5

local function ApplyPillChrome(bar, texturePath, yOffset)
    if bar._dragonuiPill then
        return
    end
    bar._dragonuiPill = true

    local left = bar:CreateTexture(nil, "BACKGROUND")
    left:SetSize(8, 17)
    left:SetPoint("LEFT", bar, "LEFT", 0, yOffset or 0)
    left:SetTexture(texturePath)
    left:SetTexCoord(0.03125, 0.53125, 0.289062, 0.554688)

    local right = bar:CreateTexture(nil, "BACKGROUND")
    right:SetSize(8, 17)
    right:SetPoint("RIGHT", bar, "RIGHT", 0, yOffset or 0)
    right:SetTexture(texturePath)
    right:SetTexCoord(0.03125, 0.53125, 0.570312, 0.835938)

    local middle = bar:CreateTexture(nil, "BACKGROUND")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    middle:SetTexture(texturePath)
    middle:SetTexCoord(0, 0.5, 0.0078125, 0.273438)
end

local function SkinMoneyFrame(frame)
    local moneyFrame = _G[frame:GetName() .. "MoneyFrame"]
    if not moneyFrame or moneyFrame._dragonuiSkinned then
        return
    end
    moneyFrame._dragonuiSkinned = true

    moneyFrame:SetHeight(BOTTOM_PILL_HEIGHT)
    ApplyPillChrome(moneyFrame, textures.coinbox, -MONEY_LIFT)
end

-- MoneyFrameTemplate rebuilds each coin's NormalTexture on every RefreshMoneyFrame, so a one-time
-- swap gets clobbered; the hook below (MoneyFrame_Update) re-applies it after every native update.
-- BLP requires power-of-two dimensions, so each 20x20 icon sits padded on a 32x32 canvas;
-- these texcoords crop back to just the icon instead of stretching the whole padded square.
local COIN_ICON_TEXCOORD = { 0.1875, 0.8125, 0.1875, 0.8125 }
local COIN_ICONS = {
    { key = "GoldButton", texture = textures.coinGold },
    { key = "SilverButton", texture = textures.coinSilver },
    { key = "CopperButton", texture = textures.coinCopper },
}

local function ModernizeCoinIcons(frame)
    if not IsActive() then
        return
    end
    if GetCVar("colorblindMode") == "1" then
        return -- Blizzard blanks the coin texture and shows text instead; don't paint over it.
    end
    if type(frame) ~= "table" then
        frame = frame and _G[frame]
    end
    if not frame then
        return
    end

    local frameName = frame:GetName()
    for _, coin in ipairs(COIN_ICONS) do
        local button = _G[frameName .. coin.key]
        local tex = button and button.GetNormalTexture and button:GetNormalTexture()
        if tex then
            tex:SetTexture(coin.texture)
            tex:SetTexCoord(unpack(COIN_ICON_TEXCOORD))
        end
    end
end

-- Blizzard_TokenUI is load-on-demand; force it so tracked currencies show without opening the Character panel first.
local function EnsureTokenUILoaded()
    if ManageBackpackTokenFrame then
        return true
    end
    if not IsAddOnLoaded("Blizzard_TokenUI") then
        LoadAddOn("Blizzard_TokenUI")
    end
    return ManageBackpackTokenFrame ~= nil
end

local function SkinTokenFrame()
    local frame = BackpackTokenFrame
    if not frame or frame._dragonuiSkinned then
        return
    end
    frame._dragonuiSkinned = true

    -- Native XML ships one unnamed BACKGROUND texture (UI-Backpack-TokenFrame); strip it for our pill.
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" then
            region:Hide()
            region:SetTexture(nil)
        end
    end

    frame:SetHeight(BOTTOM_PILL_HEIGHT)
    ApplyPillChrome(frame, textures.currencybox)
end

local function RepositionBackpackBottomWidgets(frame)
    local moneyFrame = _G[frame:GetName() .. "MoneyFrame"]
    if not moneyFrame or not moneyFrame._dragonuiSkinned then
        return
    end

    local tokenShown = BackpackTokenFrame_IsShown and BackpackTokenFrame_IsShown()

    moneyFrame:ClearAllPoints()
    if tokenShown then
        BackpackTokenFrame:ClearAllPoints()
        BackpackTokenFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
        BackpackTokenFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
        moneyFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8 + BOTTOM_PILL_HEIGHT + BOTTOM_PILL_GAP + MONEY_LIFT)
        moneyFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8 + BOTTOM_PILL_HEIGHT + BOTTOM_PILL_GAP + MONEY_LIFT)
    else
        moneyFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8 + MONEY_LIFT)
        moneyFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8 + MONEY_LIFT)
    end
end

local tokenHookInstalled = false
local function OnManageBackpackTokenFrame(backpack)
    if not IsActive() then
        return
    end
    backpack = backpack or (GetBackpackFrame and GetBackpackFrame())
    if not backpack or not backpack.GetID or backpack:GetID() ~= BACKPACK_CONTAINER then
        return
    end
    SkinTokenFrame()
    RepositionBackpackBottomWidgets(backpack)
end

local function InstallTokenHook()
    if tokenHookInstalled or not ManageBackpackTokenFrame then
        return
    end
    tokenHookInstalled = true
    hooksecurefunc("ManageBackpackTokenFrame", OnManageBackpackTokenFrame)
end

local function AdjustItemGridPosition(frame)
    if frame.size == 1 then
        return
    end

    local item1 = _G[frame:GetName() .. "Item1"]
    if not item1 then
        return
    end

    local point, relativeTo, relativePoint, x, y = item1:GetPoint(1)
    if not point then
        return
    end

    local yNudge = frame:GetID() ~= BACKPACK_CONTAINER and ITEM_GRID_Y_NUDGE or 0
    item1:SetPoint(point, relativeTo, relativePoint, x + ITEM_GRID_X_NUDGE, y + yNudge)
end

function BagSkinModule:RefreshContainerFrame(frame)
    if not IsActive() or not frame then
        return
    end

    PrepareContainerFrame(frame)

    local compact = frame.size == 1
    local bagID = frame:GetID()
    local chrome = frame._dragonuiBagChrome

    HideClassicBackgrounds(frame)
    LayoutChrome(frame, chrome, compact)
    SkinCloseButton(_G[frame:GetName() .. "CloseButton"], compact)
    DressContainerPortrait(frame, compact)
    RefreshContainerTitle(frame, compact)

    if bagID == BACKPACK_CONTAINER then
        SkinMoneyFrame(frame)
        if EnsureTokenUILoaded() then
            InstallTokenHook()
            SkinTokenFrame()
            BackpackTokenFrame_Update()
            ManageBackpackTokenFrame(frame)
        end
        RepositionBackpackBottomWidgets(frame)
    end

    for i = 1, MAX_CONTAINER_ITEMS do
        SkinItemButton(_G[frame:GetName() .. "Item" .. i], IsBankBag(bagID))
    end
end

local function ApplyContainerSpacing()
    if not IsActive() or not ContainerFrame1 or not ContainerFrame1.bags then
        return
    end

    local column = -1
    for _, frameName in ipairs(ContainerFrame1.bags) do
        local frame = _G[frameName]
        if frame then
            local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
            if point and relativeTo == frame:GetParent() then
                column = column + 1
                frame:SetPoint(
                    point,
                    relativeTo,
                    relativePoint,
                    (x or 0) - column * BAG_HORIZONTAL_GAP,
                    y or 0
                )
            elseif point and relativeTo then
                frame:SetPoint(point, relativeTo, relativePoint, x or 0, (y or 0) + BAG_VERTICAL_GAP)
            end
        end
    end
end

local function InstallHooks()
    if BagSkinModule.hooksInstalled then
        return
    end

    BagSkinModule.hooksInstalled = true

    if MoneyFrame_Update then
        hooksecurefunc("MoneyFrame_Update", ModernizeCoinIcons)
    end

    hooksecurefunc("ContainerFrame_GenerateFrame", function(frame)
        if IsActive() then
            BagSkinModule:RefreshContainerFrame(frame)
            AdjustItemGridPosition(frame)
        end
    end)

    hooksecurefunc("ContainerFrame_Update", function(frame)
        if IsActive() then
            BagSkinModule:RefreshContainerFrame(frame)
        end
    end)

    hooksecurefunc("updateContainerFrameAnchors", ApplyContainerSpacing)
end

function BagSkinModule:Apply()
    if self.applied then
        return
    end

    self.applied = true
    self.initialized = true
    InstallHooks()

    for i = 1, MAX_CONTAINER_FRAMES do
        local frame = _G["ContainerFrame" .. i]
        if frame then
            PrepareContainerFrame(frame)
            if frame:IsShown() then
                self:RefreshContainerFrame(frame)
                AdjustItemGridPosition(frame)
            end
        end
    end

    ApplyContainerSpacing()
end

function BagSkinModule:Restore()
    self.applied = false
end

-- Unusable tint is independent of bag skin chrome (works with stock bags too).
local unusableTintHooksInstalled = false

-- Re-apply after Blizzard paths that force white (Update, UpdateCooldown, UpdateLocked).
local function TintBagButtonUnusable(itemButton, bag, slot)
    if not addon:IsUnusableItemTintEnabled() or not itemButton then
        return
    end
    local texture, _, locked = GetContainerItemInfo(bag, slot)
    if not texture or locked then
        return
    end
    local _, duration, enable = GetContainerItemCooldown(bag, slot)
    if duration and duration > 0 and enable == 0 then
        return
    end
    local link = GetContainerItemLink(bag, slot)
    if addon:IsItemUnusableForTint(link, bag, slot) then
        SetItemButtonTextureVertexColor(itemButton, 0.9, 0, 0)
    end
end

local function TintContainerFrameUnusable(frame)
    if not addon:IsUnusableItemTintEnabled() or not frame then
        return
    end
    local bag = frame:GetID()
    local frameName = frame:GetName()
    local size = frame.size or GetContainerNumSlots(bag)
    for i = 1, size do
        local itemButton = _G[frameName .. "Item" .. i]
        if itemButton then
            TintBagButtonUnusable(itemButton, bag, itemButton:GetID())
        end
    end
end

local function TintBankSlotUnusable(button)
    if not button or not BankFrame or not BankFrame:IsShown() or button.isBag then
        return
    end
    TintBagButtonUnusable(button, BANK_CONTAINER or -1, button:GetID())
end

local function InstallUnusableTintHooks()
    if unusableTintHooksInstalled then
        return
    end
    unusableTintHooksInstalled = true

    hooksecurefunc("ContainerFrame_Update", TintContainerFrameUnusable)
    if ContainerFrame_UpdateCooldown then
        hooksecurefunc("ContainerFrame_UpdateCooldown", function(container, button)
            if button then
                TintBagButtonUnusable(button, container, button:GetID())
            end
        end)
    end
    -- Unlock path: SetItemButtonDesaturated(..., nil) forces white and skips our Update hook.
    if ContainerFrame_UpdateLocked then
        hooksecurefunc("ContainerFrame_UpdateLocked", TintContainerFrameUnusable)
    end
    if ContainerFrame_UpdateLockedItem then
        hooksecurefunc("ContainerFrame_UpdateLockedItem", function(frame, slot)
            if not addon:IsUnusableItemTintEnabled() or not frame or not slot then
                return
            end
            local index = (frame.size or 0) + 1 - slot
            local itemButton = _G[frame:GetName() .. "Item" .. index]
            if itemButton then
                TintBagButtonUnusable(itemButton, frame:GetID(), itemButton:GetID())
            end
        end)
    end

    if BankFrameItemButton_Update then
        hooksecurefunc("BankFrameItemButton_Update", TintBankSlotUnusable)
    end
    if BankFrameItemButton_UpdateLocked then
        hooksecurefunc("BankFrameItemButton_UpdateLocked", TintBankSlotUnusable)
    end
    if BankFrame_UpdateCooldown then
        hooksecurefunc("BankFrame_UpdateCooldown", function(container, button)
            if button then
                TintBagButtonUnusable(button, container, button:GetID())
            end
        end)
    end

    local levelFrame = CreateFrame("Frame")
    levelFrame:RegisterEvent("PLAYER_LEVEL_UP")
    levelFrame:RegisterEvent("SPELLS_CHANGED")
    -- Profession ranks land after the first bag scan at login, so recipes cache as "red" until then.
    levelFrame:RegisterEvent("SKILL_LINES_CHANGED")
    levelFrame:SetScript("OnEvent", function(_, event)
        if event == "SPELLS_CHANGED" then
            if addon.ClearUnusableItemTintCache then
                addon:ClearUnusableItemTintCache()
            end
            return
        end
        if addon.RefreshUnusableItemTints then
            addon:RefreshUnusableItemTints()
        end
    end)
end

InstallUnusableTintHooks()
