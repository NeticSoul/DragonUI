-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

-- ============================================================================
-- BAG ITEM USABILITY TINT
-- ============================================================================
-- Tooltip red misses armor/weapon proficiency in 3.3.5a; class tables cover that.
-- Not IsUsableItem: that also reports false for usable items on cooldown or out of range.

local unusableTintCache = {}
local armorSubs
local weaponSubs
local scanTip, scanTipName

-- true = always; number = min level (WotLK trainer unlock).
local CLASS_ARMOR = {
    MAGE = { cloth = true },
    PRIEST = { cloth = true },
    WARLOCK = { cloth = true },
    ROGUE = { cloth = true, leather = true },
    DRUID = { cloth = true, leather = true },
    HUNTER = { cloth = true, leather = true, mail = 40 },
    SHAMAN = { cloth = true, leather = true, mail = 40 },
    WARRIOR = { cloth = true, leather = true, mail = 40, plate = 40 },
    PALADIN = { cloth = true, leather = true, mail = true, plate = 40 },
    DEATHKNIGHT = { cloth = true, leather = true, mail = true, plate = true },
}

local CLASS_SHIELD = { WARRIOR = true, PALADIN = true, SHAMAN = true }

-- WotLK trainable weapon types per class (GetAuctionItemSubClasses(1) keys).
local CLASS_WEAPONS = {
    MAGE = { dagger = true, staff = true, sword1h = true, wand = true },
    PRIEST = { dagger = true, mace1h = true, staff = true, wand = true },
    WARLOCK = { dagger = true, staff = true, sword1h = true, wand = true },
    ROGUE = {
        bow = true, crossbow = true, dagger = true, fist = true, gun = true,
        mace1h = true, sword1h = true, thrown = true,
    },
    DRUID = {
        dagger = true, fist = true, mace1h = true, mace2h = true,
        staff = true, polearm = true,
    },
    HUNTER = {
        bow = true, crossbow = true, gun = true, dagger = true, fist = true,
        axe1h = true, axe2h = true, sword1h = true, sword2h = true,
        polearm = true, staff = true, thrown = true,
    },
    SHAMAN = {
        axe1h = true, axe2h = true, mace1h = true, mace2h = true,
        staff = true, dagger = true, fist = true,
    },
    WARRIOR = {
        axe1h = true, axe2h = true, bow = true, gun = true, mace1h = true,
        mace2h = true, polearm = true, sword1h = true, sword2h = true,
        staff = true, fist = true, dagger = true, thrown = true, crossbow = true,
    },
    PALADIN = {
        axe1h = true, axe2h = true, mace1h = true, mace2h = true,
        sword1h = true, sword2h = true, polearm = true,
    },
    DEATHKNIGHT = {
        axe1h = true, axe2h = true, mace1h = true, mace2h = true,
        sword1h = true, sword2h = true, polearm = true,
    },
}

local ARMOR_SLOTS = {
    INVTYPE_HEAD = true, INVTYPE_SHOULDER = true, INVTYPE_CHEST = true,
    INVTYPE_ROBE = true, INVTYPE_WAIST = true, INVTYPE_LEGS = true,
    INVTYPE_FEET = true, INVTYPE_WRIST = true, INVTYPE_HAND = true,
}

local WEAPON_SLOTS = {
    INVTYPE_WEAPON = true, INVTYPE_WEAPONMAINHAND = true,
    INVTYPE_WEAPONOFFHAND = true, INVTYPE_2HWEAPON = true,
    INVTYPE_RANGED = true, INVTYPE_THROWN = true, INVTYPE_RANGEDRIGHT = true,
}

local function GetArmorSubs()
    if armorSubs then return armorSubs end
    local _, cloth, leather, mail, plate, shields = GetAuctionItemSubClasses(2)
    armorSubs = { cloth = cloth, leather = leather, mail = mail, plate = plate, shields = shields }
    return armorSubs
end

-- Order: 1H/2H Axes, Bows, Guns, 1H/2H Maces, Polearms, 1H/2H Swords, Staves,
-- Fist, Misc, Daggers, Thrown, Crossbows, Wands, Fishing Poles.
local function GetWeaponSubs()
    if weaponSubs then return weaponSubs end
    local axe1h, axe2h, bow, gun, mace1h, mace2h, polearm, sword1h, sword2h,
        staff, fist, misc, dagger, thrown, crossbow, wand, fishing =
        GetAuctionItemSubClasses(1)
    weaponSubs = {
        axe1h = axe1h, axe2h = axe2h, bow = bow, gun = gun,
        mace1h = mace1h, mace2h = mace2h, polearm = polearm,
        sword1h = sword1h, sword2h = sword2h, staff = staff, fist = fist,
        misc = misc, dagger = dagger, thrown = thrown, crossbow = crossbow,
        wand = wand, fishing = fishing,
    }
    return weaponSubs
end

local function GetWeaponKey(subType)
    local s = GetWeaponSubs()
    if subType == s.axe1h then return "axe1h"
    elseif subType == s.axe2h then return "axe2h"
    elseif subType == s.bow then return "bow"
    elseif subType == s.gun then return "gun"
    elseif subType == s.mace1h then return "mace1h"
    elseif subType == s.mace2h then return "mace2h"
    elseif subType == s.polearm then return "polearm"
    elseif subType == s.sword1h then return "sword1h"
    elseif subType == s.sword2h then return "sword2h"
    elseif subType == s.staff then return "staff"
    elseif subType == s.fist then return "fist"
    elseif subType == s.dagger then return "dagger"
    elseif subType == s.thrown then return "thrown"
    elseif subType == s.crossbow then return "crossbow"
    elseif subType == s.wand then return "wand"
    elseif subType == s.fishing then return "fishing"
    elseif subType == s.misc then return "misc"
    end
    return nil
end

local function IsWrongArmorOrShield(link)
    local name, _, _, _, _, itemType, subType, _, equipLoc = GetItemInfo(link)
    if not name or not subType or not equipLoc then return nil end
    local _, classFile = UnitClass("player")
    if not classFile then return false end
    local subs = GetArmorSubs()

    if equipLoc == "INVTYPE_SHIELD" then
        return not CLASS_SHIELD[classFile]
    end
    if not ARMOR_SLOTS[equipLoc] then return false end
    if itemType ~= select(2, GetAuctionItemClasses()) then return false end

    local key = (subType == subs.cloth and "cloth")
        or (subType == subs.leather and "leather")
        or (subType == subs.mail and "mail")
        or (subType == subs.plate and "plate")
    if not key then return false end

    local req = CLASS_ARMOR[classFile] and CLASS_ARMOR[classFile][key]
    if not req then return true end
    return type(req) == "number" and UnitLevel("player") < req
end

local function IsWrongWeapon(link)
    local name, _, _, _, _, itemType, subType, _, equipLoc = GetItemInfo(link)
    if not name or not subType or not equipLoc then return nil end
    if not WEAPON_SLOTS[equipLoc] then return false end
    if itemType ~= select(1, GetAuctionItemClasses()) then return false end

    local key = GetWeaponKey(subType)
    if not key or key == "misc" or key == "fishing" then return false end

    local _, classFile = UnitClass("player")
    if not classFile then return false end
    return not (CLASS_WEAPONS[classFile] and CLASS_WEAPONS[classFile][key])
end

-- Level/skill/class/race/reputation/proficiency, equippable or not. Returns nil if tooltip empty (uncached).
local function TooltipHasRedRequirement(link, bag, slot)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "DragonUIUnusableScanTip", nil, "GameTooltipTemplate")
        scanTipName = scanTip:GetName()
    end
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    if bag ~= nil and slot ~= nil then
        scanTip:SetBagItem(bag, slot)
    else
        scanTip:SetHyperlink(link)
    end
    local numLines = scanTip:NumLines() or 0
    if numLines < 2 then
        scanTip:Hide()
        return nil
    end
    local redCode = RED_FONT_COLOR_CODE or "|cffff2020"
    local function IsRed(fs)
        if not fs or not fs:IsShown() then return false end
        local text = fs:GetText()
        if text and text:find(redCode, 1, true) then return true end
        local r, g, b = fs:GetTextColor()
        return r and r > 0.9 and g < 0.2 and b < 0.2 or false
    end
    for i = 2, numLines do
        -- Weapon/armor subtype sits on the RIGHT of its line and is what reddens for a proficiency the class lacks.
        if IsRed(_G[scanTipName .. "TextLeft" .. i]) or IsRed(_G[scanTipName .. "TextRight" .. i]) then
            scanTip:Hide()
            return true
        end
    end
    scanTip:Hide()
    return false
end

function addon:IsUnusableItemTintEnabled()
    local bags = self.db and self.db.profile and self.db.profile.bags
    return bags and bags.tint_unusable and true or false
end

function addon:ClearUnusableItemTintCache()
    wipe(unusableTintCache)
end

function addon:IsItemUnusableForTint(link, bag, slot)
    if not link then return false end
    local itemID = link:match("item:(%d+)")
    if itemID and unusableTintCache[itemID] ~= nil then
        return unusableTintCache[itemID]
    end

    local unusable
    local cacheable = true
    local wrongArmor = IsWrongArmorOrShield(link)
    local wrongWeapon = false
    if wrongArmor ~= true then
        wrongWeapon = IsWrongWeapon(link)
    end
    if wrongArmor == nil or wrongWeapon == nil then
        cacheable = false
        unusable = false
    elseif wrongArmor or wrongWeapon then
        unusable = true
    else
        local reqLevel = select(5, GetItemInfo(link))
        if reqLevel and reqLevel > UnitLevel("player") then
            unusable = true
        else
            local red = TooltipHasRedRequirement(link, bag, slot)
            if red == nil then
                cacheable = false
                unusable = false
            else
                unusable = red
            end
        end
    end

    if itemID and cacheable then
        unusableTintCache[itemID] = unusable
    end
    return unusable
end

function addon:RefreshUnusableItemTints()
    wipe(unusableTintCache)
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local frame = _G["ContainerFrame" .. i]
        if frame and frame:IsShown() and ContainerFrame_Update then
            ContainerFrame_Update(frame)
        end
    end
    if BankFrame and BankFrame:IsShown() and BankFrameItemButton_Update then
        for i = 1, 28 do
            local button = _G["BankFrameItem" .. i]
            if button then BankFrameItemButton_Update(button) end
        end
    end
    -- addon.BagsterModule.frames = inventory/bank frames only (not RegisterModule.frames).
    local frames = self.BagsterModule and self.BagsterModule.frames
    if frames then
        for i = 1, 2 do
            local frame = frames[i]
            local items = frame and frame.itemFrame and frame.itemFrame.items
            if items then
                for _, item in pairs(items) do
                    if item.UpdateSlotColor then
                        item:UpdateSlotColor()
                    end
                end
            end
        end
    end
end

