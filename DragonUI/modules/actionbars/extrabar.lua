-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...);

-- Standalone 12-button bar: type1/spell1/item1/macrotext1 only — never shares the 1-120 action slot array.
local CreateFrame = CreateFrame;
local UIParent = UIParent;
local InCombatLockdown = InCombatLockdown;
local GetCursorInfo = GetCursorInfo;
local ClearCursor = ClearCursor;
local UnitExists = UnitExists;
local config = addon.config;

local NUM_EXTRABAR_BUTTONS = 12;

-- Bindings.xml; Key Bindings UI reads BINDING_NAME_* globals (not AceLocale).
_G.BINDING_HEADER_DragonUI = "DragonUI"
for i = 1, NUM_EXTRABAR_BUTTONS do
    _G["BINDING_NAME_CLICK DragonUI_ExtraBarButton" .. i .. ":LeftButton"] = "DragonUI Extra Bar - Button " .. i
end

local ExtraBarModule = {
    initialized = false,
    applied = false,
    anchor = nil,    -- Editor Mode drag frame only (CreateUIFrame); never parents buttons
    container = nil, -- button parent; sibling of anchor so drag mouse isn't blocked by children
    buttons = {},
    ticker = nil,
}

if addon.RegisterModule then
    addon:RegisterModule("extrabar1", ExtraBarModule,
        (addon.L and addon.L["Extra Bar"]) or "Extra Bar",
        (addon.L and addon.L["A standalone action bar, independent of any class bonus bar"]) or "A standalone action bar, independent of any class bonus bar")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("extrabar1")
end

local function GetExtrabarConfig()
    return addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional.extrabar1
end

-- Bake scale into pixels (no SetScale): avoids FULLSCREEN strata / editor gaps / double-scale.
local function GetExtrabarScale()
    local cfg = GetExtrabarConfig() or {}
    if cfg.scale ~= nil then return cfg.scale end
    local mainbars = addon.db and addon.db.profile and addon.db.profile.mainbars
    return (mainbars and mainbars.scale_actionbar) or 0.9
end

local function GetSizeAndSpacing()
    local cfg = GetExtrabarConfig() or {}
    local scale = GetExtrabarScale()
    local baseSize = cfg.size or 36
    local baseSpacing = cfg.spacing
    if baseSpacing == nil then baseSpacing = 6 end
    return baseSize * scale, baseSpacing * scale
end

-- Same columns/button_order grid as mainbars (12 = one row).
local function GetGridLayout()
    local cfg = GetExtrabarConfig() or {}
    local columns = math.max(1, math.min(NUM_EXTRABAR_BUTTONS, tonumber(cfg.columns) or NUM_EXTRABAR_BUTTONS))
    local rows = math.ceil(NUM_EXTRABAR_BUTTONS / columns)
    local order = cfg.change_button_order and cfg.button_order or "bottom_left"
    if not (order == "top_left" or order == "bottom_left" or order == "top_right" or order == "bottom_right") then
        order = "bottom_left"
    end
    return columns, rows, order
end

-- Like mainbars SetBarGridButtonPoint, but with our baked size/spacing (not ACTION_BUTTON_SIZE).
local function SetGridButtonPoint(button, container, row, col, order, step)
    button:ClearAllPoints()
    local x = col * step
    local y = row * step
    if order == "top_left" then
        button:SetPoint("TOPLEFT", container, "TOPLEFT", x, -y)
    elseif order == "top_right" then
        button:SetPoint("TOPRIGHT", container, "TOPRIGHT", -x, -y)
    elseif order == "bottom_right" then
        button:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -x, y)
    else
        button:SetPoint("BOTTOMLEFT", container, "BOTTOMLEFT", x, y)
    end
end

-- Own regions (no ActionButtonTemplate); same atlas path as buttons.lua main_buttons.
local function SkinButton(button)
    button:SetNormalTexture(config.assets.normal)
    local normal = button:GetNormalTexture()
    normal:ClearAllPoints()
    normal:SetPoint('TOPRIGHT', button, 2.2, 2.3)
    normal:SetPoint('BOTTOMLEFT', button, -2.2, -2.2)
    normal:SetVertexColor(1, 1, 1, 1)
    normal:SetDrawLayer('OVERLAY')

    -- SecureActionButtonTemplate has no Checked/Pushed/Highlight — set then atlas like buttons.lua.
    button:SetCheckedTexture(config.assets.normal)
    button:SetPushedTexture(config.assets.normal)
    button:GetCheckedTexture():set_atlas('_ui-hud-actionbar-iconborder-checked')
    button:GetPushedTexture():set_atlas('_ui-hud-actionbar-iconborder-pushed')
    button:SetHighlightTexture(config.assets.highlight)
    button:GetCheckedTexture():SetAllPoints(normal)
    button:GetPushedTexture():SetAllPoints(normal)
    button:GetHighlightTexture():SetAllPoints(normal)
    button:GetCheckedTexture():SetDrawLayer('OVERLAY')
    button:GetPushedTexture():SetDrawLayer('OVERLAY')

    button.icon:SetTexCoord(.05, .95, .05, .95)
    button.icon:SetAllPoints(button)
    button.icon:SetDrawLayer('BORDER')

    -- Slot fill + outer shadow (buttons.lua setup_background(..., true)).
    if not button.shadow then
        local shadow = button:CreateTexture(nil, 'ARTWORK', nil, 1)
        shadow:SetPoint('TOPRIGHT', normal, 3.8, 3.8)
        shadow:SetPoint('BOTTOMLEFT', normal, -3.8, -3.8)
        shadow:set_atlas('ui-hud-actionbar-iconframe-flyoutbordershadow', true)
        button.shadow = shadow
    end
    if not button.background then
        local background = button:CreateTexture(nil, 'BACKGROUND')
        background:SetAllPoints(normal)
        background:set_atlas('ui-hud-actionbar-iconframe-slot')
        button.background = background
    end
    -- Hide slot fill when only_actionbackground (same as pet/stance in buttons.lua).
    local buttonsDb = addon.db and addon.db.profile and addon.db.profile.buttons
    if buttonsDb and buttonsDb.only_actionbackground then
        button.background:Hide()
    else
        button.background:Show()
    end

    -- parent+1 (not button+1) keeps the spiral under the border.
    button.cooldown:ClearAllPoints()
    button.cooldown:SetPoint('TOPRIGHT', button, -1, -1)
    button.cooldown:SetPoint('BOTTOMLEFT', button, 1, 1)
    button.cooldown:SetFrameLevel(button:GetParent():GetFrameLevel() + 1)
end

local function GetSlotsTable()
    local cfg = GetExtrabarConfig()
    if not cfg then return nil end
    cfg.slots = cfg.slots or {}
    return cfg.slots
end

local function PersistSlot(index, data)
    local slots = GetSlotsTable()
    if slots then slots[index] = data end
end

local function ApplyToButton(button, data)
    if InCombatLockdown() then
        addon.CombatQueue:Add("extrabar1_apply_" .. button:GetID(), ApplyToButton, button, data)
        return
    end

    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("macrotext1", nil)

    if not data then
        button.icon:Hide()
        return
    end

    button:SetAttribute("type1", data.type)

    if data.type == "spell" then
        button:SetAttribute("spell1", data.spell)
        local _, _, texture = GetSpellInfo(data.spell)
        if texture then
            button.icon:SetTexture(texture)
            button.icon:Show()
        end
    elseif data.type == "item" then
        button:SetAttribute("item1", "item:" .. data.item)
        local texture = GetItemIcon(data.item) or select(10, GetItemInfo(data.item))
        if texture then
            button.icon:SetTexture(texture)
            button.icon:Show()
        end
    elseif data.type == "macro" then
        button:SetAttribute("macrotext1", data.macrotext)
        if data.texture then
            button.icon:SetTexture(data.texture)
            button.icon:Show()
        end
    end
end

local function ClearSlot(button)
    PersistSlot(button:GetID(), nil)
    ApplyToButton(button, nil)
end

local function CopySlotData(data)
    if not data then return nil end
    if data.type == "spell" then
        return { type = "spell", spell = data.spell }
    elseif data.type == "item" then
        return { type = "item", item = data.item }
    elseif data.type == "macro" then
        return { type = "macro", macrotext = data.macrotext, texture = data.texture, macro = data.macro }
    end
    return nil
end

local function SnapshotSlot(button)
    local slots = GetSlotsTable()
    local saved = slots and slots[button:GetID()]
    if saved then return CopySlotData(saved) end
    local t = button:GetAttribute("type1")
    if t == "spell" then
        return { type = "spell", spell = button:GetAttribute("spell1") }
    elseif t == "item" then
        local itemId = tonumber((button:GetAttribute("item1") or ""):match("item:(%d+)"))
        if itemId then return { type = "item", item = itemId } end
    elseif t == "macro" then
        return { type = "macro", macrotext = button:GetAttribute("macrotext1") }
    end
    return nil
end

-- "Name(Rank N)" with no space before '(' (GetSpellLink / CastSpellByName).
local function SpellNameWithRank(index, bookType)
    local name, rank = GetSpellName(index, bookType)
    if not name then return nil end
    if rank and rank ~= "" then
        return name .. "(" .. rank .. ")"
    end
    return name
end

local function IsRankText(text)
    if not text or text == "" then return false end
    if (RANK and text:find(RANK, 1, true) == 1)
        or text:match("^Rank%s+%d")
        or text:match("^Rango%s+%d") then
        return true
    end
    return false
end

-- Strip Rank secondary text only — not names with parentheses (e.g. Faerie Fire (Feral)).
local function BareSpellName(spellName)
    if not spellName then return nil end
    local bare, inner = spellName:match("^(.+)%(([^%)]*)%)$")
    if bare and IsRankText(inner) then
        return bare
    end
    return spellName
end

-- PickupSpell needs a book index. Exact "Name(Rank N)" wins; bare name → last match (max rank).
local function FindSpellBookSlot(spellName)
    if not spellName then return nil end
    local found
    local i = 1
    while true do
        local name, rank = GetSpellName(i, BOOKTYPE_SPELL)
        if not name then break end
        local full = (rank and rank ~= "") and (name .. "(" .. rank .. ")") or name
        if full == spellName then return i end
        if name == spellName then found = i end -- legacy saves / names with parentheses
        i = i + 1
    end
    local bare = BareSpellName(spellName)
    if bare and bare ~= spellName then
        return FindSpellBookSlot(bare)
    end
    return found
end

local function GetActionSpellName(slot)
    local actionType, id, subType, spellID = GetActionInfo(slot)
    if actionType ~= "spell" or subType == "pet" or subType == BOOKTYPE_PET then
        return nil
    end
    -- 3.3.5a: 4th return is spellID; some clients put spellID in `id` — try both.
    if spellID then
        local name = GetSpellInfo(spellID)
        if name then return name, spellID end
    end
    local name = SpellNameWithRank(id, subType or BOOKTYPE_SPELL)
    if name then return BareSpellName(name), nil end
    if id then
        return GetSpellInfo(id), id
    end
    return nil
end

-- Bare-name action-slot cache for GCD/tooltips; hits + misses (invalidate on bar changes).
local actionSlotCache = {}
local function InvalidateActionSlotCache()
    wipe(actionSlotCache)
end

local function FindActionSlotBySpellName(spellName)
    if not spellName then return nil end
    local bare = BareSpellName(spellName)
    local cached = actionSlotCache[bare]
    if cached == false then return nil end
    if cached then
        if BareSpellName(GetActionSpellName(cached)) == bare then
            return cached
        end
        actionSlotCache[bare] = nil
    end
    for i = 1, 120 do
        if BareSpellName(GetActionSpellName(i)) == bare then
            actionSlotCache[bare] = i
            return i
        end
    end
    actionSlotCache[bare] = false
    return nil
end

local function TooltipHasRankLine(rank)
    for i = 1, (GameTooltip:NumLines() or 0) do
        local left = _G["GameTooltipTextLeft" .. i]
        local right = _G["GameTooltipTextRight" .. i]
        local lt = left and left:GetText()
        local rt = right and right:GetText()
        if (rank and (lt == rank or rt == rank)) or IsRankText(lt) or IsRankText(rt) then
            return true
        end
    end
    return false
end

-- Paint rank into an empty top-right tooltip slot; never shift existing lines.
local function EnsureSpellRankLine(rank)
    if not rank or rank == "" or TooltipHasRankLine(rank) then return end
    local right1 = GameTooltipTextRight1
    if right1 and (not right1:GetText() or right1:GetText() == "") then
        right1:SetText(rank)
        right1:SetTextColor(0.5, 0.5, 0.5)
        right1:Show()
        return
    end
    local left2 = GameTooltipTextLeft2
    if left2 and (not left2:GetText() or left2:GetText() == "") then
        left2:SetText(rank)
        left2:SetTextColor(0.5, 0.5, 0.5)
        left2:Show()
    end
end

local function ResolveSpellRank(name, preferred)
    if preferred and preferred ~= "" then return preferred end
    local slot = FindSpellBookSlot(name)
    if slot then
        local _, bookRank = GetSpellName(slot, BOOKTYPE_SPELL)
        if bookRank and bookRank ~= "" then return bookRank end
    end
    local _, infoRank = GetSpellInfo(name)
    if infoRank and infoRank ~= "" then return infoRank end
    return nil
end

-- Second return: rank for EnsureSpellRankLine, or nil if SetAction already laid out Rank.
local function SetTooltipByName(name, rank)
    if not name or name == "" then return false, nil end
    rank = ResolveSpellRank(name, rank)
    -- Parenthesized names: spellbook first so SetAction doesn't show a different main-bar rank.
    if name:find("(", 1, true) then
        local slot = FindSpellBookSlot(name)
        if slot then
            GameTooltip:SetSpell(slot, BOOKTYPE_SPELL)
            local _, bookRank = GetSpellName(slot, BOOKTYPE_SPELL)
            return true, rank or bookRank
        end
    end
    local actionSlot = FindActionSlotBySpellName(name)
    if actionSlot then
        GameTooltip:SetAction(actionSlot)
        return true, nil
    end
    local slot = FindSpellBookSlot(name)
    if slot then
        GameTooltip:SetSpell(slot, BOOKTYPE_SPELL)
        local _, bookRank = GetSpellName(slot, BOOKTYPE_SPELL)
        return true, rank or bookRank
    end
    local link = GetSpellLink(name)
    if link then
        local spellId = tonumber(link:match("spell:(%d+)"))
        if spellId and GameTooltip.SetSpellByID then
            GameTooltip:SetSpellByID(spellId)
        else
            GameTooltip:SetHyperlink(link)
        end
        return true, rank
    end
    local _, itemLink = GetItemInfo(name)
    if itemLink then
        GameTooltip:SetHyperlink(itemLink)
        return true, nil
    end
    GameTooltip:SetText(name)
    return true, rank
end

local function SetExtrabarTooltip(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    local t = self:GetAttribute("type1")
    local rankToEnsure
    if t == "spell" then
        local spellName = self:GetAttribute("spell1")
        local ok, rank = SetTooltipByName(spellName)
        if ok then rankToEnsure = rank end
    elseif t == "item" then
        local link = self:GetAttribute("item1")
        if link then GameTooltip:SetHyperlink(link) end
    elseif t == "macro" then
        local slots = GetSlotsTable()
        local data = slots and slots[self:GetID()]
        local macroIdx = data and data.macro
        local body = (data and data.macrotext) or self:GetAttribute("macrotext1")
        local showArg = body and body:match("#showtooltip([^\n]*)")
        local shown
        if showArg then
            showArg = strtrim(showArg)
            if showArg ~= "" then
                local ok, rank = SetTooltipByName(showArg)
                shown = ok
                rankToEnsure = rank
            end
        end
        if not shown and macroIdx then
            local spellName, spellRank = GetMacroSpell(macroIdx)
            if spellName then
                local ok, rank = SetTooltipByName(spellName, spellRank)
                shown = ok
                rankToEnsure = rank
            else
                local _, itemLink = GetMacroItem(macroIdx)
                if itemLink then
                    GameTooltip:SetHyperlink(itemLink)
                    shown = true
                end
            end
        end
        if not shown then
            local name = macroIdx and GetMacroInfo(macroIdx)
            GameTooltip:SetText(name or MACRO or "Macro")
        end
    else
        GameTooltip:SetText((addon.L and addon.L["Drag a spell, item or macro here."]) or "Drag a spell, item or macro here.")
    end
    GameTooltip:Show()
    if rankToEnsure then
        EnsureSpellRankLine(rankToEnsure)
        GameTooltip:Show()
    end
    self.UpdateTooltip = SetExtrabarTooltip
end

local function PutDataOnCursor(data)
    if not data then return end
    if data.type == "spell" then
        local slot = FindSpellBookSlot(data.spell)
        if slot then PickupSpell(slot, BOOKTYPE_SPELL) end
    elseif data.type == "item" then
        PickupItem(data.item)
    elseif data.type == "macro" and data.macro then
        PickupMacro(data.macro)
    end
end

-- false = reject (clear cursor); nil = unsupported cursor type (leave alone).
local function CursorToData()
    local kind, a, b = GetCursorInfo()
    if not kind then return nil end

    if kind == "spell" then
        if b == "pet" or b == BOOKTYPE_PET then return false end -- secure spell = player book only
        local spellName = SpellNameWithRank(a, b)
        if not spellName then return false end
        return { type = "spell", spell = spellName }
    elseif kind == "item" then
        return { type = "item", item = a }
    elseif kind == "macro" then
        local _, texture, body = GetMacroInfo(a)
        return { type = "macro", macrotext = body, texture = texture, macro = a }
    elseif kind == "action" then
        -- Native bar drag: GetCursorInfo is ("action", slot).
        local actionType, id, subType = GetActionInfo(a)
        if actionType == "spell" then
            if subType == "pet" or subType == BOOKTYPE_PET then return false end
            local spellName = SpellNameWithRank(id, subType or BOOKTYPE_SPELL)
            if not spellName then return false end
            return { type = "spell", spell = spellName }
        elseif actionType == "item" then
            return { type = "item", item = id }
        elseif actionType == "macro" then
            local _, texture, body = GetMacroInfo(id)
            return { type = "macro", macrotext = body, texture = texture, macro = id }
        end
        return false
    end
    return nil
end

-- PlaceAction-style swap. Debounced: OnReceiveDrag + PreClick can both fire.
local lastAssignTime = {}
local function AssignFromCursor(button)
    if InCombatLockdown() then
        if GetCursorInfo() then ClearCursor() end
        return false
    end

    local now = GetTime()
    if lastAssignTime[button] and (now - lastAssignTime[button]) < 0.1 then
        return false
    end

    local data = CursorToData()
    if data == nil then return false end
    if data == false then
        ClearCursor()
        return false
    end

    lastAssignTime[button] = now
    local previous = SnapshotSlot(button)
    ClearCursor()
    PersistSlot(button:GetID(), data)
    ApplyToButton(button, data)
    if previous then
        PutDataOnCursor(previous)
    end
    return true
end

-- No action slot → IsActionInRange unavailable; melee uses CheckInteractDistance (~10 yd).
local function SafeIsSpellInRange(spellName)
    if not spellName or not UnitExists("target") or UnitIsDead("target") then
        return nil
    end
    local result = IsSpellInRange(spellName, "target")
    if result == 1 then return true end
    if result == 0 then return false end
    if IsHarmfulSpell(spellName) and UnitCanAttack("player", "target") and not SpellHasRange(spellName) then
        return CheckInteractDistance("target", 3) and true or false
    end
    return nil
end

-- Same 1/0/nil as IsSpellInRange; nil = no range UI for this item.
local function SafeIsItemInRange(itemId)
    if not itemId or not UnitExists("target") or UnitIsDead("target") then
        return nil
    end
    local result = IsItemInRange(itemId, "target")
    if result == 1 then return true end
    if result == 0 then return false end
    return nil
end

-- Reuse rage_indicator.lua colors/flag (config only).
local function GetRangeIndicatorColors()
    local cfg = addon:GetModuleConfig("rage_indicator")
    local oor = cfg and cfg.oor_color
    local oom = cfg and cfg.oom_color
    return (oor and oor.r) or 0.8, (oor and oor.g) or 0.2, (oor and oor.b) or 0.2,
           (oom and oom.r) or 0.5, (oom and oom.g) or 0.5, (oom and oom.b) or 1.0
end

local function IsRangeIndicatorEnabled()
    local cfg = addon:GetModuleConfig("rage_indicator")
    return cfg and cfg.enabled
end

-- ARIALN: RANGE_INDICATOR glyph (expressway lacks it); CJK/ruRU remapped in fonts.lua.
local HOTKEY_FONT = addon.Fonts.ARIALN

local function IsRangeDotEnabled()
    local db = addon.db and addon.db.profile and addon.db.profile.buttons
    return db and db.hotkey and db.hotkey.range
end

local function ApplyRangeIndicator(button, rangeValid)
    if button.hotkeyBound then
        button.hotkey:Show()
        if rangeValid == false then
            button.hotkey:SetVertexColor(1.0, 0.1, 0.1)
        else
            button.hotkey:SetVertexColor(0.6, 0.6, 0.6)
        end
    elseif button.hotkeyDotEligible then
        if rangeValid == nil then
            button.hotkey:Hide()
        else
            button.hotkey:SetText(RANGE_INDICATOR)
            button.hotkey:Show()
            if rangeValid == false then
                button.hotkey:SetVertexColor(1.0, 0.1, 0.1)
            else
                button.hotkey:SetVertexColor(0.6, 0.6, 0.6)
            end
        end
    else
        button.hotkey:Hide()
    end
end

-- Cooldown hot path only; tooltips/pickup keep uncached FindSpellBookSlot.
local bookSlotCache = {}
local function InvalidateBookSlotCache()
    wipe(bookSlotCache)
end

local function FindSpellBookSlotCached(spellName)
    if not spellName then return nil end
    local cached = bookSlotCache[spellName]
    if cached == false then return nil end
    if cached then
        local name, rank = GetSpellName(cached, BOOKTYPE_SPELL)
        if name then
            local full = (rank and rank ~= "") and (name .. "(" .. rank .. ")") or name
            if full == spellName or name == spellName then
                return cached
            end
        end
        bookSlotCache[spellName] = nil
    end
    local slot = FindSpellBookSlot(spellName)
    bookSlotCache[spellName] = slot or false
    return slot
end

-- Prefer GetActionCooldown (GCD); GetSpellCooldown(name) can omit it on some clients.
local function GetButtonSpellCooldown(spellName)
    if not spellName then return 0, 0, 0 end
    local actionSlot = FindActionSlotBySpellName(spellName)
    if actionSlot then
        return GetActionCooldown(actionSlot)
    end
    local bookSlot = FindSpellBookSlotCached(spellName)
    if bookSlot then
        return GetSpellCooldown(bookSlot, BOOKTYPE_SPELL)
    end
    return GetSpellCooldown(spellName)
end

-- enable=0 on GCD would hide the swipe; skip identical SetTimer to avoid finish bling.
local function ApplyCooldown(cooldown, start, duration, enable)
    start, duration, enable = start or 0, duration or 0, enable or 0
    if enable == 0 and duration > 0 and duration <= 1.5 then
        enable = 1
    end
    if cooldown._ebStart == start and cooldown._ebDuration == duration and cooldown._ebEnable == enable then
        return
    end
    cooldown._ebStart, cooldown._ebDuration, cooldown._ebEnable = start, duration, enable
    CooldownFrame_SetTimer(cooldown, start, duration, enable)
end

-- IsCurrentAction equivalent for non-slot SecureActionButtons.
local function SpellIsCurrent(spellName)
    if not spellName then return nil end
    if IsCurrentSpell(spellName) or IsAutoRepeatSpell(spellName) then return true end
    local base = spellName:match("^(.-)%(")
    if base and (IsCurrentSpell(base) or IsAutoRepeatSpell(base)) then return true end
    return nil
end

local function IsButtonCurrent(button)
    local slotType = button:GetAttribute("type1")
    if slotType == "spell" then
        return SpellIsCurrent(button:GetAttribute("spell1"))
    elseif slotType == "item" then
        local item = button:GetAttribute("item1")
        return item and IsCurrentItem(item)
    elseif slotType == "macro" then
        local slots = GetSlotsTable()
        local data = slots and slots[button:GetID()]
        local macroIdx = data and data.macro
        if not macroIdx then return nil end
        local spellName = GetMacroSpell(macroIdx)
        if spellName then return SpellIsCurrent(spellName) end
        local _, itemLink = GetMacroItem(macroIdx)
        return itemLink and IsCurrentItem(itemLink)
    end
    return nil
end

local function UpdateCheckedState(button)
    -- Keep checked during key PUSHED flash (mouse keeps both after PostClick).
    button:SetChecked(IsButtonCurrent(button) and 1 or 0)
end

local function UpdateButtonState(button)
    local slotType = button:GetAttribute("type1")
    if not slotType then
        button.cooldown:Hide()
        button.count:SetText("")
        button.icon:SetVertexColor(1, 1, 1)
        ApplyRangeIndicator(button, nil)
        UpdateCheckedState(button)
        return
    end

    if slotType == "spell" then
        local spellName = button:GetAttribute("spell1")
        ApplyCooldown(button.cooldown, GetButtonSpellCooldown(spellName))
        button.count:SetText("")

        local isUsable, notEnoughMana = IsUsableSpell(spellName)
        local rangeValid = SafeIsSpellInRange(spellName)
        local oorR, oorG, oorB, oomR, oomG, oomB = GetRangeIndicatorColors()
        if not isUsable and notEnoughMana then
            button.icon:SetVertexColor(oomR, oomG, oomB)
        elseif not isUsable then
            button.icon:SetVertexColor(0.4, 0.4, 0.4)
        elseif IsRangeIndicatorEnabled() and rangeValid == false then
            button.icon:SetVertexColor(oorR, oorG, oorB)
        else
            button.icon:SetVertexColor(1, 1, 1)
        end
        ApplyRangeIndicator(button, rangeValid)
    elseif slotType == "item" then
        local itemAttr = button:GetAttribute("item1")
        local itemId = itemAttr and tonumber(itemAttr:match("item:(%d+)"))
        if not itemId then
            UpdateCheckedState(button)
            return
        end

        ApplyCooldown(button.cooldown, GetItemCooldown(itemId))

        local count = GetItemCount(itemId) -- ActionButton_UpdateCount: show 0+; never hide sole charge
        if count > (button.maxDisplayCount or 9999) then
            button.count:SetText("*")
        else
            button.count:SetText(count)
        end

        local rangeValid = SafeIsItemInRange(itemId)
        local oorR, oorG, oorB = GetRangeIndicatorColors()
        if not IsUsableItem(itemId) then
            button.icon:SetVertexColor(0.4, 0.4, 0.4)
        elseif IsRangeIndicatorEnabled() and rangeValid == false then
            button.icon:SetVertexColor(oorR, oorG, oorB)
        else
            button.icon:SetVertexColor(1, 1, 1)
        end
        ApplyRangeIndicator(button, rangeValid)
    elseif slotType == "macro" then
        local slots = GetSlotsTable()
        local data = slots and slots[button:GetID()]
        local macroIdx = data and data.macro
        local start, duration, enable = 0, 0, 0
        if macroIdx then
            local spellName = GetMacroSpell(macroIdx)
            if spellName then
                start, duration, enable = GetButtonSpellCooldown(spellName)
            else
                local _, itemLink = GetMacroItem(macroIdx)
                local itemId = itemLink and tonumber(itemLink:match("item:(%d+)"))
                if itemId then
                    start, duration, enable = GetItemCooldown(itemId)
                end
            end
        end
        ApplyCooldown(button.cooldown, start, duration, enable)
        button.count:SetText("")
        button.icon:SetVertexColor(1, 1, 1)
        ApplyRangeIndicator(button, nil)
    end

    UpdateCheckedState(button)
end

local LibKeyBound = LibStub("LibKeyBound-1.0", true) -- same short labels as keybinding.lua

local function UpdateHotkeyText(button)
    local cfg = GetExtrabarConfig()
    if not cfg or cfg.show_hotkey == false then
        button.hotkey:SetText("")
        button.hotkeyBound = false
        button.hotkeyDotEligible = false
        button.hotkey:Hide()
        return
    end

    local key = GetBindingKey("CLICK " .. button:GetName() .. ":LeftButton")
    if key then
        button.hotkeyBound = true
        button.hotkeyDotEligible = false
        button.hotkey:SetText(LibKeyBound and LibKeyBound:ToShortKey(key) or "")
        button.hotkey:SetVertexColor(0.6, 0.6, 0.6)
        button.hotkey:Show()
    else
        button.hotkeyBound = false
        button.hotkeyDotEligible = IsRangeDotEnabled() and true or false
        button.hotkey:SetText(button.hotkeyDotEligible and RANGE_INDICATOR or "")
        button.hotkey:Hide()
    end
end

-- No IsKeyDown in 3.3.5a; CLICK binds get a short PUSHED flash instead of ActionButtonDown/Up.
local KEY_PUSH_FLASH = 0.12
local keyPushUntil = {}
local keyPushFrame = CreateFrame("Frame")
keyPushFrame:Hide()
keyPushFrame:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local any
    for button, untilTime in pairs(keyPushUntil) do
        if now >= untilTime then
            button._extrabarKeyPushed = nil
            keyPushUntil[button] = nil
            button:SetButtonState("NORMAL")
            UpdateCheckedState(button)
        else
            any = true
        end
    end
    if not any then self:Hide() end
end)

local function HookKeyPushFlash(button)
    button:HookScript("OnMouseDown", function(self)
        self._extrabarFromMouse = true
    end)
    button:HookScript("OnClick", function(self)
        if self._extrabarFromMouse then
            self._extrabarFromMouse = nil
            return
        end
        if self._extrabarKeyPushed then return end
        self._extrabarKeyPushed = true
        self:SetButtonState("PUSHED")
        keyPushUntil[self] = GetTime() + KEY_PUSH_FLASH
        keyPushFrame:Show()
    end)
end

-- Same as ActionBarButtonTemplate OnDragStart: locked unless PICKUPACTION (default Shift).
local function OnDragStart(self)
    if InCombatLockdown() then return end
    if GetCVar("lockActionBars") == "1" and not IsModifiedClick("PICKUPACTION") then return end

    local previous = SnapshotSlot(self)
    if not previous then return end

    ClearSlot(self)
    PutDataOnCursor(previous)
end

local function CreateExtrabarButton(index, parent)
    local name = "DragonUI_ExtraBarButton" .. index
    -- CheckButton like ActionBarButtonTemplate — same Checked/Pushed texture path as buttons.lua.
    local button = _G[name]
    if not button then
        button = CreateFrame("CheckButton", name, parent, "SecureActionButtonTemplate")
    end
    button:SetID(index)
    button:SetParent(parent)
    button:RegisterForClicks("AnyUp")
    button:RegisterForDrag("LeftButton")

    -- Truthy .action so cooldowns.lua's SetCooldown hook paints text on our frame.
    button.action = index

    if not button.icon then
        local icon = button:CreateTexture(nil, "BORDER")
        icon:Hide()
        button.icon = icon

        button.cooldown = CreateFrame("Cooldown", name .. "Cooldown", button, "CooldownFrameTemplate")

        -- Named $parentCount + NumberFontNormal: same as ActionButtonTemplate / other bars.
        local count = button:CreateFontString(name .. "Count", "OVERLAY")
        count:SetFontObject(NumberFontNormal)
        count:SetJustifyH("RIGHT")
        count:SetPoint("BOTTOMRIGHT", -2, 2)
        button.count = count

        SkinButton(button)

        -- OVERLAY sublevel 7: above SkinButton's border (also OVERLAY).
        local hotkey = button:CreateFontString(nil, "OVERLAY")
        hotkey:SetDrawLayer("OVERLAY", 7)
        hotkey:SetFont(HOTKEY_FONT, 12, "OUTLINE")
        hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        hotkey:SetJustifyH("RIGHT")
        hotkey:SetVertexColor(0.6, 0.6, 0.6)
        -- Same depth as buttons.lua / pretty hotkeys (black shadow down-left).
        hotkey:SetShadowOffset(-1.3, -1.1)
        local shadow = addon.db and addon.db.profile and addon.db.profile.buttons
            and addon.db.profile.buttons.hotkey and addon.db.profile.buttons.hotkey.shadow
        hotkey:SetShadowColor(unpack(shadow or {0, 0, 0, 1}))
        button.hotkey = hotkey

        button:SetScript("OnDragStart", function(self)
            self._extrabarFromMouse = nil
            OnDragStart(self)
        end)
        button:SetScript("OnReceiveDrag", AssignFromCursor)
        HookKeyPushFlash(button)
        -- Click-drop + suppress cast; SetChecked(0) like PetActionButton (stops toggle stick).
        button:SetScript("PreClick", function(self)
            self:SetChecked(0)
            local placed = AssignFromCursor(self)
            local justPlaced = lastAssignTime[self] and (GetTime() - lastAssignTime[self]) < 0.1
            if (placed or justPlaced) and not InCombatLockdown() then
                self:SetAttribute("type1", nil)
                self._extrabarRestoreType = true
            end
        end)
        button:SetScript("PostClick", function(self)
            if self._extrabarRestoreType and not InCombatLockdown() then
                self._extrabarRestoreType = nil
                local slots = GetSlotsTable()
                local data = slots and slots[self:GetID()]
                if data then self:SetAttribute("type1", data.type) end
            end
            UpdateCheckedState(self)
        end)
        button:SetScript("OnEnter", SetExtrabarTooltip)
        button:SetScript("OnLeave", function() GameTooltip:Hide() end)

        -- After OnEnter SetScript: MakeButtonBindable HookScript is wiped by a later SetScript.
        if addon.KeyBindingModule then
            addon.KeyBindingModule:MakeButtonBindable(button, "CLICK " .. name .. ":LeftButton",
                "DragonUI Extra Bar - Button " .. index)
        end
    end

    return button
end

local function CreateButtons(container)
    if InCombatLockdown() then
        addon.CombatQueue:Add("extrabar1_create_buttons", CreateButtons, container)
        return
    end

    local size, spacing = GetSizeAndSpacing()
    local columns, _, order = GetGridLayout()
    local step = size + spacing

    for index = 1, NUM_EXTRABAR_BUTTONS do
        local button = CreateExtrabarButton(index, container)
        button:SetSize(size, size)
        local gridIndex = index - 1
        local row = math.floor(gridIndex / columns)
        local col = gridIndex % columns
        SetGridButtonPoint(button, container, row, col, order, step)
        button:Show()
        ExtraBarModule.buttons[index] = button
    end
end

local function ReapplySavedSlots()
    local slots = GetSlotsTable()
    if not slots then return end
    for index, button in pairs(ExtraBarModule.buttons) do
        ApplyToButton(button, slots[index])
    end
end

-- widgets.extrabar1 after first drag; else additional.extrabar1 x/y (Editor Mode).
local function GetContainerSize()
    local size, spacing = GetSizeAndSpacing()
    local columns, rows = GetGridLayout()
    local width = (size * columns) + (spacing * (columns - 1))
    local height = (size * rows) + (spacing * (rows - 1))
    return width, height
end

local function ApplyAnchorPosition(anchor)
    local widgetConfig = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.extrabar1
    anchor:ClearAllPoints()
    if widgetConfig and (widgetConfig.anchor or widgetConfig.posX or widgetConfig.posY) then
        local anchorPoint = widgetConfig.anchor or "CENTER"
        anchor:SetPoint(anchorPoint, UIParent, anchorPoint, widgetConfig.posX or 0, widgetConfig.posY or 0)
    else
        local cfg = GetExtrabarConfig() or {}
        anchor:SetPoint("CENTER", UIParent, "CENTER", cfg.x_position or 0, cfg.y_position or 260)
    end
end

local function CreateAnchor()
    if ExtraBarModule.anchor then return ExtraBarModule.anchor end

    local width, height = GetContainerSize()
    -- CreateUIFrame (not bare CreateFrame) registers Editor Mode drag like other widgets.
    local anchor = _G.DragonUI_ExtraBar1 or addon.CreateUIFrame(width, height, "ExtraBar1")
    anchor:SetSize(width, height)

    ApplyAnchorPosition(anchor)
    anchor:SetScale(1)

    ExtraBarModule.anchor = anchor
    return anchor
end

-- Sibling of editor anchor on UIParent (petbar); never FULLSCREEN or buttons cover menus.
local function CreateContainer(anchor)
    local container = ExtraBarModule.container or _G.DragonUI_ExtraBar1Container
        or CreateFrame("Frame", "DragonUI_ExtraBar1Container", UIParent)
    container:SetParent(UIParent)
    container:SetAllPoints(anchor)
    container:SetScale(1)
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(5)

    ExtraBarModule.container = container
    return container
end

local UPDATE_INTERVAL = 0.1

local function RefreshAllButtonStates()
    if not ExtraBarModule.container or not ExtraBarModule.container:IsVisible() then return end
    for _, button in pairs(ExtraBarModule.buttons) do
        UpdateButtonState(button)
    end
end

local function Ticker_OnUpdate(self, elapsed)
    self.elapsed = self.elapsed + elapsed
    if self.elapsed < UPDATE_INTERVAL then return end
    self.elapsed = 0
    RefreshAllButtonStates()
end

local function StartTicker()
    local ticker = ExtraBarModule.ticker
    if not ticker then
        ticker = CreateFrame("Frame")
        ExtraBarModule.ticker = ticker
    end
    ticker.elapsed = 0
    ticker:SetScript("OnUpdate", Ticker_OnUpdate)
end

local function StopTicker()
    if ExtraBarModule.ticker then
        ExtraBarModule.ticker:SetScript("OnUpdate", nil)
    end
end

local function RefreshAllHotkeys()
    for _, button in pairs(ExtraBarModule.buttons) do
        UpdateHotkeyText(button)
    end
end

-- Sole owner of ExtraBar1Container [vehicleui] driver (VehicleMenuBar:IsShown is wrong with artstyle).
local function IsVehicleArtStyle()
    local v = addon.db and addon.db.profile and addon.db.profile.additional
        and addon.db.profile.additional.vehicle
    return v and v.artstyle
end

local function SetupExtrabarVehicleVisibility()
    if not ExtraBarModule.container then return end
    if InCombatLockdown() then
        addon.CombatQueue:Add("extrabar1_vehicle_vis", SetupExtrabarVehicleVisibility)
        return
    end

    local container = ExtraBarModule.container
    if IsVehicleArtStyle() then
        RegisterStateDriver(container, "visibility", "[vehicleui] hide; show")
    else
        UnregisterStateDriver(container, "visibility")
        if not (addon.EditorMode and addon.EditorMode:IsActive()) then
            container:Show()
            if addon.VisibilityFade then
                addon.VisibilityFade.Update("extrabar1")
            end
        end
    end
end

local function ClearExtrabarVehicleVisibility()
    if not ExtraBarModule.container or InCombatLockdown() then return end
    UnregisterStateDriver(ExtraBarModule.container, "visibility")
end

-- Alpha-only hover/combat fade (VisibilityFade); layered on the vehicle state driver.
local function RegisterVisibilityFade()
    local hoverFrames = { ExtraBarModule.container }
    for _, button in pairs(ExtraBarModule.buttons) do
        table.insert(hoverFrames, button)
    end

    addon.VisibilityFade.Register("extrabar1", ExtraBarModule.container, {
        dbTable = GetExtrabarConfig,
        hoverFrames = hoverFrames,
        clickThrough = true,
    })
    addon.VisibilityFade.Update("extrabar1")
end

-- Editor Mode drags the anchor; container SetAllPoints it (buttons are not anchor children).
local function UpdateEditorFrameRegistration()
    if addon.EditableFrames and addon.EditableFrames.extrabar1 and ExtraBarModule.anchor then
        addon.EditableFrames.extrabar1.frame = ExtraBarModule.anchor
        local width, height = GetContainerSize()
        ExtraBarModule.anchor:SetSize(width, height)
    end
end

local function ShowExtrabarTest()
    if not ExtraBarModule.anchor then return end
    ExtraBarModule.anchor:Show()
    ExtraBarModule.anchor:SetMovable(true)
    ExtraBarModule.anchor:EnableMouse(true)
    if ExtraBarModule.anchor.editorTexture then ExtraBarModule.anchor.editorTexture:Show() end
    if ExtraBarModule.anchor.editorText then ExtraBarModule.anchor.editorText:Show() end

    -- [vehicleui] driver blocks :Show(); drop it while the editor overlay is active.
    if ExtraBarModule.container and not InCombatLockdown() then
        UnregisterStateDriver(ExtraBarModule.container, "visibility")
        ExtraBarModule.container:Show()
        ExtraBarModule.container:SetAlpha(1)
    end
end

local function HideExtrabarTest()
    if not ExtraBarModule.anchor then return end
    ExtraBarModule.anchor:SetMovable(false)
    ExtraBarModule.anchor:EnableMouse(false)
    if ExtraBarModule.anchor.editorTexture then ExtraBarModule.anchor.editorTexture:Hide() end
    if ExtraBarModule.anchor.editorText then ExtraBarModule.anchor.editorText:Hide() end

    if addon.SaveUIFramePosition then
        addon.SaveUIFramePosition(ExtraBarModule.anchor, "widgets", "extrabar1")
    end

    SetupExtrabarVehicleVisibility()
    if addon.VisibilityFade then
        addon.VisibilityFade.Update("extrabar1")
    end
end

local function ApplyExtrabarSystem()
    if ExtraBarModule.applied or not IsModuleEnabled() then return end

    local anchor = CreateAnchor()
    local container = CreateContainer(anchor)
    CreateButtons(container)
    ReapplySavedSlots()
    RefreshAllHotkeys()
    StartTicker()

    ExtraBarModule.applied = true
    ExtraBarModule.initialized = true

    if addon.VisibilityFade then
        RegisterVisibilityFade()
    end
    SetupExtrabarVehicleVisibility()
    UpdateEditorFrameRegistration()
end

local function RestoreExtrabarSystem()
    if not ExtraBarModule.applied then return end

    StopTicker()
    ClearExtrabarVehicleVisibility()
    if addon.VisibilityFade then
        addon.VisibilityFade.Reset("extrabar1", 1)
    end
    if ExtraBarModule.container then ExtraBarModule.container:Hide() end

    ExtraBarModule.applied = false
end

function addon.RefreshExtrabarSystem()
    if InCombatLockdown() then
        addon.CombatQueue:Add("extrabar1_refresh_system", addon.RefreshExtrabarSystem)
        return
    end

    if ExtraBarModule.applied then
        if not IsModuleEnabled() then
            RestoreExtrabarSystem()
        else
            addon.RefreshExtrabarFrame()
            ReapplySavedSlots()
            RefreshAllHotkeys()
            SetupExtrabarVehicleVisibility()
            if addon.VisibilityFade then
                addon.VisibilityFade.Update("extrabar1")
            end
        end
    elseif IsModuleEnabled() then
        ApplyExtrabarSystem()
    end
end

function addon.RefreshExtrabarHotkeys()
    RefreshAllHotkeys()
end

-- Live layout refresh (options sliders); no teardown — same shape as RefreshPetbarFrame.
function addon.RefreshExtrabarFrame()
    if not ExtraBarModule.anchor then return end
    if InCombatLockdown() then
        addon.CombatQueue:Add("extrabar1_refresh_frame", addon.RefreshExtrabarFrame)
        return
    end

    local width, height = GetContainerSize()
    ExtraBarModule.anchor:SetSize(width, height)
    ExtraBarModule.anchor:SetScale(1)
    ApplyAnchorPosition(ExtraBarModule.anchor)

    if ExtraBarModule.container then
        ExtraBarModule.container:SetParent(UIParent)
        ExtraBarModule.container:SetAllPoints(ExtraBarModule.anchor)
        ExtraBarModule.container:SetScale(1)
        ExtraBarModule.container:SetFrameStrata("MEDIUM")
        ExtraBarModule.container:SetFrameLevel(5)
    end

    local size, spacing = GetSizeAndSpacing()
    local columns, _, order = GetGridLayout()
    local step = size + spacing
    for index = 1, NUM_EXTRABAR_BUTTONS do
        local button = ExtraBarModule.buttons[index]
        if button then
            button:SetSize(size, size)
            local gridIndex = index - 1
            local row = math.floor(gridIndex / columns)
            local col = gridIndex % columns
            SetGridButtonPoint(button, ExtraBarModule.container, row, col, order, step)
        end
    end

    UpdateEditorFrameRegistration()
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("UPDATE_BINDINGS")
initFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
initFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
initFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
initFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
initFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
initFrame:RegisterEvent("SPELLS_CHANGED")
initFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
initFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        self.addonLoaded = true

        if addon.RegisterEditableFrame then
            addon:RegisterEditableFrame({
                name = "extrabar1",
                frame = nil, -- set once the anchor is actually created
                configPath = {"widgets", "extrabar1"},
                showTest = ShowExtrabarTest,
                hideTest = HideExtrabarTest,
                editorVisible = IsModuleEnabled, -- hide editor overlay when module disabled
            })
        end

        if addon.db then
            addon.db.RegisterCallback(ExtraBarModule, "OnProfileChanged", function()
                addon.RefreshExtrabarSystem()
            end)
            addon.db.RegisterCallback(ExtraBarModule, "OnProfileCopied", function()
                addon.RefreshExtrabarSystem()
            end)
            addon.db.RegisterCallback(ExtraBarModule, "OnProfileReset", function()
                addon.RefreshExtrabarSystem()
            end)
        end
    elseif event == "PLAYER_LOGIN" and self.addonLoaded then
        addon.RefreshExtrabarSystem()
        SetupExtrabarVehicleVisibility()
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ACTIONBAR_SLOT_CHANGED" then
        InvalidateActionSlotCache()
    elseif event == "SPELLS_CHANGED" then
        InvalidateBookSlotCache()
    elseif event == "UPDATE_BINDINGS" then
        RefreshAllHotkeys()
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN"
        or event == "BAG_UPDATE_COOLDOWN" then
        -- Ticker alone can miss the start of a short GCD swipe.
        if ExtraBarModule.applied then
            RefreshAllButtonStates()
        end
    elseif event == "ACTIONBAR_UPDATE_STATE"
        or event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
        if ExtraBarModule.applied then
            RefreshAllButtonStates()
        end
    end
end)
