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
    slot = assets .. "bagsitemslot2x",
    bankSlot = assets .. "bagsitembankslot2x",
    metal = assets .. "uiframemetal2x",
    metalHorizontal = assets .. "uiframemetalhorizontal2x",
    metalVertical = assets .. "uiframemetalvertical2x",
    background = assets .. "ui-background-rock",
    close = assets .. "redbutton2x",
    pushed = assets .. "ui-quickslot-depress",
    highlight = assets .. "buttonhilight-square",
    slotBorder = assets .. "ui-quickslot2",
    coinbox = assets .. "commoncoinbox",
    -- pre-masked (round alpha baked in offline, no runtime mask API exists in 3.3.5a)
    backpackIcon = assets .. "INV_Misc_Bag_08_round",
}

-- Native layout splits CONTAINER_WIDTH's 29px slack 17/12 left-right; this recenters the grid.
local ITEM_GRID_X_NUDGE = -2.5
local ITEM_GRID_Y_NUDGE = 3

-- Same clearances the corner ornament (portrait) and close button already reserve elsewhere.
local TITLE_LEFT_CLEARANCE = 58
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

local function EnsureChrome(frame, key, portraitKind)
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
        portraitKind = portraitKind,
    }

    local background = frame:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(textures.background)
    -- Retail's FlatPanelBackgroundTemplate tints this bg with PANEL_BACKGROUND_COLOR, alpha 0.8.
    background:SetAlpha(0.8)
    chrome.background = background

    frame[key] = chrome
    return chrome
end

local function LayoutChrome(frame, chrome, compact)
    local leftOffset = chrome.portraitKind and -13 or -8
    local topSize = compact and 52 or 75
    local topHeight = compact and 52 or 75
    local bottomSize = compact and 24 or 32
    local topY = compact and 11 or 16
    local bottomY = compact and -2 or -3
    local rightOffset = compact and 3 or 4

    local topLeftTop = 0.00195312
    local topLeftBottom = 0.294922
    if chrome.portraitKind == "small" then
        topLeftTop = 0.595703
        topLeftBottom = 0.888672
    elseif chrome.portraitKind == "large" then
        topLeftTop = 0.298828
        topLeftBottom = 0.591797
    end

    ConfigureTexture(
        chrome.topLeft,
        textures.metal,
        topSize,
        topHeight,
        0.00195312,
        0.294922,
        topLeftTop,
        topLeftBottom
    )
    chrome.topLeft:ClearAllPoints()
    chrome.topLeft:SetPoint("TOPLEFT", frame, "TOPLEFT", compact and -9 or leftOffset, topY)

    ConfigureTexture(
        chrome.topRight,
        textures.metal,
        topSize,
        topHeight,
        0.298828,
        0.591797,
        0.00195312,
        0.294922
    )
    chrome.topRight:ClearAllPoints()
    chrome.topRight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", rightOffset, topY)

    ConfigureTexture(
        chrome.bottomLeft,
        textures.metal,
        bottomSize,
        bottomSize,
        0.298828,
        0.423828,
        0.298828,
        0.423828
    )
    chrome.bottomLeft:ClearAllPoints()
    chrome.bottomLeft:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", compact and -9 or leftOffset, bottomY)

    ConfigureTexture(
        chrome.bottomRight,
        textures.metal,
        bottomSize,
        bottomSize,
        0.427734,
        0.552734,
        0.298828,
        0.423828
    )
    chrome.bottomRight:ClearAllPoints()
    chrome.bottomRight:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", rightOffset, bottomY)

    ConfigureTexture(
        chrome.top,
        textures.metalHorizontal,
        32,
        topHeight,
        0,
        1,
        0.00390625,
        0.589844
    )
    chrome.top:ClearAllPoints()
    chrome.top:SetPoint("TOPLEFT", chrome.topLeft, "TOPRIGHT")
    chrome.top:SetPoint("TOPRIGHT", chrome.topRight, "TOPLEFT")

    ConfigureTexture(
        chrome.bottom,
        textures.metalHorizontal,
        16,
        bottomSize,
        0,
        0.5,
        0.597656,
        0.847656
    )
    chrome.bottom:ClearAllPoints()
    chrome.bottom:SetPoint("TOPLEFT", chrome.bottomLeft, "TOPRIGHT")
    chrome.bottom:SetPoint("TOPRIGHT", chrome.bottomRight, "TOPLEFT")

    ConfigureTexture(
        chrome.left,
        textures.metalVertical,
        topSize,
        16,
        0.00195312,
        0.294922,
        0,
        1
    )
    chrome.left:ClearAllPoints()
    chrome.left:SetPoint("TOPLEFT", chrome.topLeft, "BOTTOMLEFT")
    chrome.left:SetPoint("BOTTOMLEFT", chrome.bottomLeft, "TOPLEFT")

    ConfigureTexture(
        chrome.right,
        textures.metalVertical,
        topSize,
        16,
        0.298828,
        0.591797,
        0,
        1
    )
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

    button:SetSize(compact and 20 or 24, compact and 20 or 24)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", button:GetParent(), "TOPRIGHT", 1, 0)

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

local function RefreshContainerPortrait(frame, compact)
    local name = frame:GetName()
    local portrait = _G[name .. "Portrait"]
    local portraitButton = _G[name .. "PortraitButton"]
    local bagID = frame:GetID()
    local size = compact and 28 or 36
    local x = compact and -2 or -4
    local y = compact and 0 or 1

    if portrait then
        if bagID == KEYRING_CONTAINER then
            SetPortraitToTexture(portrait, "Interface\\ContainerFrame\\KeyRing-Bag-Icon")
        elseif bagID == BACKPACK_CONTAINER then
            -- SetPortraitToTexture over-crops this edge-to-edge HD asset; masked offline instead.
            portrait:SetTexture(textures.backpackIcon)
            portrait:SetTexCoord(0, 1, 0, 1)
        elseif type(bagID) == "number" then
            SetBagPortraitTexture(portrait, bagID)
        end

        portrait:SetSize(size, size)
        portrait:ClearAllPoints()
        portrait:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
        portrait:SetDrawLayer("BORDER")
        portrait:Show()
    end

    if portraitButton then
        portraitButton:SetSize(size, size)
        portraitButton:ClearAllPoints()
        portraitButton:SetPoint("TOPLEFT", frame, "TOPLEFT", x, y)
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
    local chrome = EnsureChrome(frame, "_dragonuiBagChrome", "small")
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

local function SkinMoneyFrame(frame)
    local moneyFrame = _G[frame:GetName() .. "MoneyFrame"]
    if not moneyFrame or moneyFrame._dragonuiSkinned then
        return
    end
    moneyFrame._dragonuiSkinned = true

    moneyFrame:ClearAllPoints()
    moneyFrame:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 8, 8)
    moneyFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    moneyFrame:SetHeight(17)

    local left = moneyFrame:CreateTexture(nil, "BACKGROUND")
    left:SetSize(8, 17)
    left:SetPoint("LEFT", moneyFrame, "LEFT")
    left:SetTexture(textures.coinbox)
    left:SetTexCoord(0.03125, 0.53125, 0.289062, 0.554688)

    local right = moneyFrame:CreateTexture(nil, "BACKGROUND")
    right:SetSize(8, 17)
    right:SetPoint("RIGHT", moneyFrame, "RIGHT")
    right:SetTexture(textures.coinbox)
    right:SetTexCoord(0.03125, 0.53125, 0.570312, 0.835938)

    local middle = moneyFrame:CreateTexture(nil, "BACKGROUND")
    middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
    middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    middle:SetTexture(textures.coinbox)
    middle:SetTexCoord(0, 0.5, 0.0078125, 0.273438)
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
    RefreshContainerPortrait(frame, compact)
    RefreshContainerTitle(frame, compact)

    if bagID == BACKPACK_CONTAINER then
        SkinMoneyFrame(frame)
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
