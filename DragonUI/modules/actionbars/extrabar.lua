-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...);

-- Standalone bars: type1/spell1/item1/macrotext1 only — never share the 1-120 action slot array.
local CreateFrame = CreateFrame;
local UIParent = UIParent;
local InCombatLockdown = InCombatLockdown;
local GetCursorInfo = GetCursorInfo;
local ClearCursor = ClearCursor;
local UnitExists = UnitExists;
local config = addon.config;

-- ARIALN: RANGE_INDICATOR glyph (expressway lacks it); CJK/ruRU remapped in fonts.lua.
local HOTKEY_FONT = addon.Fonts.ARIALN
local LibKeyBound = LibStub("LibKeyBound-1.0", true) -- same short labels as keybinding.lua

local bars = {}

-- ============================================================================
-- Store: db.char.extrabar[bar.id][i] = spell{spell,spellID?}|item{item}|macro{macrotext,texture,macro}
-- |companion{companionType,creatureID,spell,spellID,texture}.
-- ============================================================================

-- Slider 7 must match MultiBars@7. Users who dialed 6 for the old visual mismatch → 7 once.
local function EnsureExtrabarSpacingDefault(cfg)
    if not cfg or cfg.spacing_visual_v2 then return end
    cfg.spacing_visual_v2 = true
    if cfg.spacing == 6 then
        cfg.spacing = 7
    end
end

local function Bar_GetConfig(bar)
    local cfg = addon.db and addon.db.profile and addon.db.profile.additional and addon.db.profile.additional[bar.id]
    if cfg and bar.id == "extrabar1" then
        EnsureExtrabarSpacingDefault(cfg)
    end
    return cfg
end

local function CopySlotData(data)
    if not data then return nil end
    if data.type == "spell" then
        return { type = "spell", spell = data.spell, spellID = data.spellID }
    elseif data.type == "item" then
        return { type = "item", item = data.item }
    elseif data.type == "macro" then
        return { type = "macro", macrotext = data.macrotext, texture = data.texture, macro = data.macro }
    elseif data.type == "companion" then
        return { type = "companion", companionType = data.companionType, creatureID = data.creatureID,
            spell = data.spell, spellID = data.spellID, texture = data.texture }
    end
    return nil
end

-- Per character, not per profile: profiles are shared between alts, spell assignments are not.
local function Bar_GetSlots(bar)
    local char = addon.db and addon.db.char
    if not char then return nil end
    local store = char.extrabar
    if type(store) ~= "table" then
        store = {}
        char.extrabar = store
    end
    local slots = store[bar.id]
    if type(slots) ~= "table" then
        slots = {}
        store[bar.id] = slots
    end
    return slots
end

local function Bar_PersistSlot(bar, index, data)
    local slots = Bar_GetSlots(bar)
    if slots then slots[index] = data end
end

-- ============================================================================
-- Layout config
-- ============================================================================

local function Bar_GetScale(bar)
    local cfg = Bar_GetConfig(bar) or {}
    if cfg.scale ~= nil then return cfg.scale end
    local mainbars = addon.db and addon.db.profile and addon.db.profile.mainbars
    return (mainbars and mainbars.scale_actionbar) or 0.9
end

-- Logical units; visual size comes from container SetScale (same model as mainbars).
-- Match ActionButton1's live size when present — hardcoded 36 can read slightly small vs MultiBars.
local function Bar_GetButtonSize()
    local ref = _G.ActionButton1
    if ref then
        local w = ref:GetWidth()
        if w and w > 0 then return w end
    end
    return 36
end

local function Bar_GetSizeAndSpacing(bar)
    local cfg = Bar_GetConfig(bar) or {}
    local spacing = cfg.spacing
    if spacing == nil then spacing = 7 end
    -- ActionButton NormalTexture overhang eats ~1px of the gap; Extra chrome does not.
    -- Layout uses spacing-1 so the same slider value matches MultiBars visually.
    local gap = spacing
    if gap > 0 then
        gap = gap - 1
    end
    return Bar_GetButtonSize(), gap
end

-- Same columns/buttons_shown/button_order grid as mainbars.
local function Bar_GetGridLayout(bar)
    local cfg = Bar_GetConfig(bar) or {}
    local shown = math.max(1, math.min(bar.numButtons, tonumber(cfg.buttons_shown) or bar.numButtons))
    local columns = math.max(1, math.min(shown, tonumber(cfg.columns) or bar.numButtons))
    local rows = math.ceil(shown / columns)
    local order = cfg.change_button_order and cfg.button_order or "bottom_left"
    if not (order == "top_left" or order == "bottom_left" or order == "top_right" or order == "bottom_right") then
        order = "bottom_left"
    end
    return columns, rows, order, shown
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

-- widgets.<id> after first drag; else additional.<id> x/y (Editor Mode).
local function Bar_GetContainerSize(bar)
    local size, spacing = Bar_GetSizeAndSpacing(bar)
    local columns, rows = Bar_GetGridLayout(bar)
    local width = (size * columns) + (spacing * (columns - 1))
    local height = (size * rows) + (spacing * (rows - 1))
    return width, height
end

-- Anchor (editor overlay) wraps the visible scaled bar, like mainbars overlay sizing.
local function Bar_GetAnchorSize(bar)
    local width, height = Bar_GetContainerSize(bar)
    local scale = Bar_GetScale(bar)
    return width * scale, height * scale
end

-- ============================================================================
-- Skin
-- ============================================================================

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

-- ============================================================================
-- Spell resolution — name/rank/spellID → book slot / action slot (shared caches)
-- ============================================================================

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
local function FindSpellBookSlotByName(spellName)
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
        return FindSpellBookSlotByName(bare)
    end
    return found
end

local function SpellNameFromID(spellID)
    if not spellID then return nil end
    local name, rank = GetSpellInfo(spellID)
    if not name then return nil end
    if rank and rank ~= "" then
        return name .. "(" .. rank .. ")"
    end
    return name
end

-- Saved names can come from another locale/rank; spellID rebuilds the live name.
local function FindSpellBookSlot(spellName, spellID)
    local slot = FindSpellBookSlotByName(spellName)
    if slot then return slot end
    local idName = SpellNameFromID(spellID)
    if idName and idName ~= spellName then
        return FindSpellBookSlotByName(idName)
    end
    return nil
end

-- Self-heal: saved spell name unknown on this client but spellID resolves → persist the live name.
local function HealSpellName(data)
    if not data or data.type ~= "spell" or not data.spellID then return end
    if FindSpellBookSlotByName(data.spell) then return end
    local liveName = SpellNameFromID(data.spellID)
    if liveName and liveName ~= data.spell and FindSpellBookSlotByName(liveName) then
        data.spell = liveName
    end
end

-- ============================================================================
-- Companions (mounts / non-combat pets)
-- ============================================================================

-- Indices shift when companions are learned/unlearned; creatureID/spellID are the stable keys.
local companionIndexCache = {}
local function InvalidateCompanionIndexCache()
    wipe(companionIndexCache)
end

local function CompanionMatches(data, index)
    local creatureID, _, spellID = GetCompanionInfo(data.companionType, index)
    if not creatureID then return false end
    if data.creatureID then return creatureID == data.creatureID end
    return data.spellID ~= nil and spellID == data.spellID
end

local function FindCompanionIndex(data)
    if not data or not data.companionType then return nil end
    local key = data.companionType .. ":" .. tostring(data.creatureID or data.spellID)
    local cached = companionIndexCache[key]
    if cached == false then return nil end
    if cached then
        if CompanionMatches(data, cached) then return cached end
        companionIndexCache[key] = nil
    end
    for i = 1, (GetNumCompanions(data.companionType) or 0) do
        if CompanionMatches(data, i) then
            companionIndexCache[key] = i
            return i
        end
    end
    companionIndexCache[key] = false
    return nil
end

-- Snapshot enough to rebuild the button after /reload without the companion list being open.
local function CompanionSlotData(companionType, index)
    if not index or (companionType ~= "MOUNT" and companionType ~= "CRITTER") then return false end
    local creatureID, creatureName, spellID, icon = GetCompanionInfo(companionType, index)
    if not spellID then return false end
    local name = GetSpellInfo(spellID) or creatureName
    if not name then return false end
    return { type = "companion", companionType = companionType, creatureID = creatureID,
        spell = name, spellID = spellID, texture = icon }
end

-- GetActionTexture swaps to the lit icon while its form/stance is active; emulate for non-slot buttons.
local function GetActiveShapeshiftTexture(data)
    local numForms = GetNumShapeshiftForms() or 0
    if numForms == 0 then return nil end
    local target = BareSpellName(data.spell)
    local idName = data.spellID and GetSpellInfo(data.spellID) or nil
    for i = 1, numForms do
        local texture, name, isActive = GetShapeshiftFormInfo(i)
        if isActive and name and (name == target or name == idName) then
            return texture
        end
    end
    return nil
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

-- Cooldown hot path only; tooltips/pickup keep uncached FindSpellBookSlot.
local bookSlotCache = {}
local function InvalidateBookSlotCache()
    wipe(bookSlotCache)
end

local function FindSpellBookSlotCached(spellName, spellID)
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
    local slot = FindSpellBookSlot(spellName, spellID)
    bookSlotCache[spellName] = slot or false
    return slot
end

-- Prefer GetActionCooldown (GCD); GetSpellCooldown(name) can omit it on some clients.
local function GetButtonSpellCooldown(spellName, spellID)
    if not spellName then return 0, 0, 0 end
    local actionSlot = FindActionSlotBySpellName(spellName)
    if actionSlot then
        return GetActionCooldown(actionSlot)
    end
    local bookSlot = FindSpellBookSlotCached(spellName, spellID)
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

-- ============================================================================
-- Range / usable / checked helpers
-- ============================================================================

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

local function IsRangeDotEnabled()
    local db = addon.db and addon.db.profile and addon.db.profile.buttons
    return db and db.hotkey and db.hotkey.range
end

local function ApplyBoundHotkeyColor(hotkey)
    if addon.GetHotkeyBoundColor then
        hotkey:SetVertexColor(addon.GetHotkeyBoundColor())
    else
        hotkey:SetVertexColor(0.6, 0.6, 0.6)
    end
end

local function ApplyRangeIndicator(button, rangeValid)
    if button.hotkeyBound then
        button.hotkey:Show()
        if rangeValid == false then
            button.hotkey:SetVertexColor(1.0, 0.1, 0.1)
        else
            ApplyBoundHotkeyColor(button.hotkey)
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

-- IsCurrentAction equivalent for non-slot SecureActionButtons.
local function SpellIsCurrent(spellName)
    if not spellName then return nil end
    if IsCurrentSpell(spellName) or IsAutoRepeatSpell(spellName) then return true end
    local base = spellName:match("^(.-)%(")
    if base and (IsCurrentSpell(base) or IsAutoRepeatSpell(base)) then return true end
    return nil
end

local function IsButtonCurrent(button)
    local companion = button:GetSlotData()
    if companion and companion.type == "companion" then
        local index = FindCompanionIndex(companion)
        local active = index and select(5, GetCompanionInfo(companion.companionType, index))
        return active and true or nil
    end
    local slotType = button:GetAttribute("type1")
    if slotType == "spell" then
        return SpellIsCurrent(button:GetAttribute("spell1"))
    elseif slotType == "item" then
        local item = button:GetAttribute("item1")
        return item and IsCurrentItem(item)
    elseif slotType == "macro" then
        local data = button:GetSlotData()
        local macroIdx = data and data.macro
        if not macroIdx then return nil end
        local spellName = GetMacroSpell(macroIdx)
        if spellName then return SpellIsCurrent(spellName) end
        local _, itemLink = GetMacroItem(macroIdx)
        return itemLink and IsCurrentItem(itemLink)
    end
    return nil
end

local function ButtonItemID(button)
    local itemAttr = button:GetAttribute("item1")
    return itemAttr and tonumber(itemAttr:match("item:(%d+)"))
end

-- ============================================================================
-- Tooltip
-- ============================================================================

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
local function SetTooltipByName(name, rank, spellID)
    if not name or name == "" then return false, nil end
    rank = ResolveSpellRank(name, rank)
    -- Parenthesized names: spellbook first so SetAction doesn't show a different main-bar rank.
    if name:find("(", 1, true) then
        local slot = FindSpellBookSlot(name, spellID)
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
    local slot = FindSpellBookSlot(name, spellID)
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
    -- Foreign-locale saves: name lookups fail but the stored spellID still resolves.
    if spellID then
        GameTooltip:SetHyperlink("spell:" .. spellID)
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
    local companion = self:GetSlotData()
    if companion and companion.type == "companion" then
        if companion.spellID then
            GameTooltip:SetHyperlink("spell:" .. companion.spellID)
        else
            GameTooltip:SetText(companion.spell or "")
        end
        GameTooltip:Show()
        self.UpdateTooltip = SetExtrabarTooltip
        return
    end
    local t = self:GetAttribute("type1")
    local rankToEnsure
    if t == "spell" then
        local spellName = self:GetAttribute("spell1")
        local data = self:GetSlotData()
        local ok, rank = SetTooltipByName(spellName, nil, data and data.spellID)
        if ok then rankToEnsure = rank end
    elseif t == "item" then
        local link = self:GetAttribute("item1")
        if link then GameTooltip:SetHyperlink(link) end
    elseif t == "macro" then
        local data = self:GetSlotData()
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
        GameTooltip:SetText(addon.L["Drag a spell, item or macro here."])
    end
    GameTooltip:Show()
    if rankToEnsure then
        EnsureSpellRankLine(rankToEnsure)
        GameTooltip:Show()
    end
    self.UpdateTooltip = SetExtrabarTooltip
end

-- ============================================================================
-- Secure layer — sole writer of secure attributes
-- ============================================================================

local Secure = {}

-- 3.3.5a SECURE_ACTIONS has no "companion" and CallCompanion is protected: cast the summon spell.
local function SecureTypeFor(data)
    if not data then return nil end
    if data.type == "companion" then return "spell" end
    return data.type
end

-- Stock action bars auto-upgrade to the current highest rank; a "Name(Rank N)" attribute pins that
-- rank forever. Only ShowAllSpellRanks (per-rank spellbook rows) means the user really wants that pin.
local function SecureSpellName(data)
    if GetCVarBool("ShowAllSpellRanks") then
        return data.spell
    end
    return BareSpellName(data.spell)
end

function Secure.Apply(button, data)
    if InCombatLockdown() then
        addon.CombatQueue:Add(button.bar.id .. "_apply_" .. button:GetID(), Secure.Apply, button, data)
        return
    end

    button:SetAttribute("type1", nil)
    button:SetAttribute("spell1", nil)
    button:SetAttribute("item1", nil)
    button:SetAttribute("macrotext1", nil)

    if data then
        button:SetAttribute("type1", SecureTypeFor(data))
        if data.type == "spell" then
            button:SetAttribute("spell1", SecureSpellName(data))
        elseif data.type == "companion" then
            button:SetAttribute("spell1", data.spell)
        elseif data.type == "item" then
            button:SetAttribute("item1", "item:" .. data.item)
        elseif data.type == "macro" then
            button:SetAttribute("macrotext1", data.macrotext)
        end
    end
    button:UpdateGridVisibility()
end

-- PreClick/PostClick cast-suppression toggle; callers already check InCombatLockdown.
function Secure.SetType1(button, t)
    button:SetAttribute("type1", t)
end

-- ============================================================================
-- Cursor / drag
-- ============================================================================

local function PutDataOnCursor(data)
    if not data then return end
    if data.type == "spell" then
        local slot = FindSpellBookSlot(data.spell, data.spellID)
        if slot then PickupSpell(slot, BOOKTYPE_SPELL) end
    elseif data.type == "item" then
        PickupItem(data.item)
    elseif data.type == "macro" and data.macro then
        PickupMacro(data.macro)
    elseif data.type == "companion" then
        local index = FindCompanionIndex(data)
        if index then PickupCompanion(data.companionType, index) end
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
        local link = GetSpellLink(a, b)
        local spellID = link and tonumber(link:match("spell:(%d+)"))
        return { type = "spell", spell = spellName, spellID = spellID }
    elseif kind == "item" then
        return { type = "item", item = a }
    elseif kind == "macro" then
        local _, texture, body = GetMacroInfo(a)
        return { type = "macro", macrotext = body, texture = texture, macro = a }
    elseif kind == "companion" then
        -- ("companion", index, "MOUNT"|"CRITTER")
        return CompanionSlotData(b, a)
    elseif kind == "action" then
        -- Native bar drag: GetCursorInfo is ("action", slot).
        local actionType, id, subType, actionSpellID = GetActionInfo(a)
        if actionType == "spell" then
            if subType == "pet" or subType == BOOKTYPE_PET then return false end
            local spellName = SpellNameWithRank(id, subType or BOOKTYPE_SPELL)
            if not spellName then return false end
            local spellID = tonumber(actionSpellID)
            if not spellID then
                local link = GetSpellLink(id, subType or BOOKTYPE_SPELL)
                spellID = link and tonumber(link:match("spell:(%d+)"))
            end
            return { type = "spell", spell = spellName, spellID = spellID }
        elseif actionType == "item" then
            return { type = "item", item = id }
        elseif actionType == "macro" then
            local _, texture, body = GetMacroInfo(id)
            return { type = "macro", macrotext = body, texture = texture, macro = id }
        elseif actionType == "companion" then
            return CompanionSlotData(subType, id)
        end
        return false
    end
    return nil
end

local function SnapshotSlot(button)
    local saved = button:GetSlotData()
    if saved then return CopySlotData(saved) end
    local t = button:GetAttribute("type1")
    if t == "spell" then
        return { type = "spell", spell = button:GetAttribute("spell1") }
    elseif t == "item" then
        local itemId = ButtonItemID(button)
        if itemId then return { type = "item", item = itemId } end
    elseif t == "macro" then
        return { type = "macro", macrotext = button:GetAttribute("macrotext1") }
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
    Bar_PersistSlot(button.bar, button:GetID(), data)
    button:SetSlotData(data)
    if previous then
        PutDataOnCursor(previous)
    end
    return true
end

-- Same as ActionBarButtonTemplate OnDragStart: locked unless PICKUPACTION (default Shift).
local function OnDragStart(self)
    if InCombatLockdown() then return end
    if GetCVar("lockActionBars") == "1" and not IsModifiedClick("PICKUPACTION") then return end

    local previous = SnapshotSlot(self)
    if not previous then return end

    self:Clear()
    PutDataOnCursor(previous)
end

-- ============================================================================
-- Key push flash
-- ============================================================================

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
            button:UpdateChecked()
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

-- ============================================================================
-- Button prototype — instance → proto → widget metatable chain (Bartender pattern)
-- ============================================================================

local ButtonProto = CreateFrame("CheckButton")
local ButtonProto_MT = { __index = ButtonProto }

function ButtonProto:GetSlotData()
    local slots = Bar_GetSlots(self.bar)
    return slots and slots[self:GetID()]
end

function ButtonProto:UpdateIcon(data)
    if not data then
        self.icon:Hide()
        return
    end
    local texture
    if data.type == "spell" then
        texture = GetActiveShapeshiftTexture(data) or select(3, GetSpellInfo(data.spell))
        if not texture and data.spellID then
            texture = select(3, GetSpellInfo(data.spellID))
        end
    elseif data.type == "item" then
        texture = GetItemIcon(data.item) or select(10, GetItemInfo(data.item))
    elseif data.type == "macro" then
        texture = data.texture
    elseif data.type == "companion" then
        texture = data.texture or (data.spellID and select(3, GetSpellInfo(data.spellID)))
    end
    if texture then
        self.icon:SetTexture(texture)
        self.icon:Show()
    end
end

local function SetMacroNameFont(nameFS, macros)
    local font = macros and macros.font
    if font and font[1] and font[2] then
        nameFS:SetFont(font[1], font[2], font[3])
    else
        nameFS:SetFont(HOTKEY_FONT, 10, "OUTLINE")
    end
    -- A path that fails to load leaves the FontString fontless, and any later SetText errors out.
    if not nameFS:GetFont() then
        nameFS:SetFontObject(GameFontHighlightSmallOutline)
    end
end

-- Same source as buttons.lua RefreshButtons: profile.buttons.macros (ARIALN+OUTLINE + color).
local function ApplyMacroNameStyle(nameFS)
    local macros = addon.db and addon.db.profile and addon.db.profile.buttons
        and addon.db.profile.buttons.macros
    -- Font before any early return: the hidden branch still calls SetText.
    SetMacroNameFont(nameFS, macros)
    if not macros then
        return true
    end
    if macros.show == false then
        nameFS:Hide()
        nameFS:SetText("")
        return false
    end
    nameFS:Show()
    if macros.color then
        nameFS:SetVertexColor(unpack(macros.color))
    end
    return true
end

-- ActionButton Name label; style from buttons.macros — only on slot change / UPDATE_MACROS / RefreshButtons.
function ButtonProto:UpdateName()
    local nameFS = self.name
    if not nameFS then return end
    if not ApplyMacroNameStyle(nameFS) then return end
    local data = self:GetSlotData()
    if data and data.type == "macro" and data.macro then
        nameFS:SetText(GetMacroInfo(data.macro) or "")
    else
        nameFS:SetText("")
    end
end

-- Applies data to the live button (secure + visual); persistence is the caller's job.
function ButtonProto:SetSlotData(data)
    HealSpellName(data)
    Secure.Apply(self, data)
    self:UpdateIcon(data)
    self:UpdateName()
    local bar = self.bar
    if bar then
        bar:RequestRefresh()
        bar:UpdateRangePolling()
    end
end

function ButtonProto:Clear()
    Bar_PersistSlot(self.bar, self:GetID(), nil)
    self:SetSlotData(nil)
end

-- Empty slots follow Blizzard alwaysShowActionBars (FrameXML MultiActionBars / ActionButton showgrid).
function ButtonProto:HasContent()
    return self:GetAttribute("type1") ~= nil
end

function ButtonProto:UpdateGridVisibility()
    if InCombatLockdown() then
        addon.CombatQueue:Add(self.bar.id .. "_grid_" .. self:GetID(), self.UpdateGridVisibility, self)
        return
    end
    local index = self:GetID()
    local _, _, _, shown = Bar_GetGridLayout(self.bar)
    if index > shown then
        self:Hide()
        return
    end
    if addon.EditorMode and addon.EditorMode:IsActive() then
        self:Show()
        return
    end
    if self:HasContent() or self.bar:ShouldShowEmpty() then
        self:Show()
    else
        self:Hide()
    end
end

function ButtonProto:UpdateCooldown()
    local companion = self:GetSlotData()
    if companion and companion.type == "companion" then
        local index = FindCompanionIndex(companion)
        if index then
            ApplyCooldown(self.cooldown, GetCompanionCooldown(companion.companionType, index))
        else
            ApplyCooldown(self.cooldown, 0, 0, 0)
        end
        return
    end
    local t = self:GetAttribute("type1")
    if t == "spell" then
        local data = self:GetSlotData()
        ApplyCooldown(self.cooldown, GetButtonSpellCooldown(self:GetAttribute("spell1"), data and data.spellID))
    elseif t == "item" then
        local itemId = ButtonItemID(self)
        if itemId then
            ApplyCooldown(self.cooldown, GetItemCooldown(itemId))
        end
    elseif t == "macro" then
        local data = self:GetSlotData()
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
        ApplyCooldown(self.cooldown, start, duration, enable)
    else
        self.cooldown:Hide()
    end
end

function ButtonProto:UpdateCount()
    if self:GetAttribute("type1") == "item" then
        local itemId = ButtonItemID(self)
        -- ActionButton_UpdateCount only shows count for consumable/stackable actions; maxStack>1 emulates that.
        local maxStack = itemId and select(8, GetItemInfo(itemId))
        if maxStack and maxStack > 1 then
            local count = GetItemCount(itemId)
            if count > (self.maxDisplayCount or 9999) then
                self.count:SetText("*")
            else
                self.count:SetText(count)
            end
            return
        end
    end
    self.count:SetText("")
end

function ButtonProto:UpdateUsable()
    local companion = self:GetSlotData()
    if companion and companion.type == "companion" then
        self.icon:SetVertexColor(1, 1, 1)
        ApplyRangeIndicator(self, nil)
        return
    end
    local t = self:GetAttribute("type1")
    local spellName, itemId
    if t == "spell" then
        spellName = self:GetAttribute("spell1")
    elseif t == "item" then
        itemId = ButtonItemID(self)
    elseif t == "macro" then
        -- Same resolve path as UpdateCooldown / IsButtonCurrent (GetMacroSpell → GetMacroItem).
        local data = self:GetSlotData()
        local macroIdx = data and data.macro
        if macroIdx then
            spellName = GetMacroSpell(macroIdx)
            if not spellName then
                local _, itemLink = GetMacroItem(macroIdx)
                itemId = itemLink and tonumber(itemLink:match("item:(%d+)"))
            end
        end
    else
        self.icon:SetVertexColor(1, 1, 1)
        ApplyRangeIndicator(self, nil)
        return
    end

    if spellName then
        local isUsable, notEnoughMana = IsUsableSpell(spellName)
        local rangeValid = SafeIsSpellInRange(spellName)
        local oorR, oorG, oorB, oomR, oomG, oomB = GetRangeIndicatorColors()
        if not isUsable and notEnoughMana then
            self.icon:SetVertexColor(oomR, oomG, oomB)
        elseif not isUsable then
            self.icon:SetVertexColor(0.4, 0.4, 0.4)
        elseif IsRangeIndicatorEnabled() and rangeValid == false then
            self.icon:SetVertexColor(oorR, oorG, oorB)
        else
            self.icon:SetVertexColor(1, 1, 1)
        end
        ApplyRangeIndicator(self, rangeValid)
    elseif itemId then
        local rangeValid = SafeIsItemInRange(itemId)
        local oorR, oorG, oorB = GetRangeIndicatorColors()
        if not IsUsableItem(itemId) then
            self.icon:SetVertexColor(0.4, 0.4, 0.4)
        elseif IsRangeIndicatorEnabled() and rangeValid == false then
            self.icon:SetVertexColor(oorR, oorG, oorB)
        else
            self.icon:SetVertexColor(1, 1, 1)
        end
        ApplyRangeIndicator(self, rangeValid)
    else
        self.icon:SetVertexColor(1, 1, 1)
        ApplyRangeIndicator(self, nil)
    end
end

-- Range and OOR tint are coupled; polled together while a target exists.
function ButtonProto:UpdateRange()
    self:UpdateUsable()
end

function ButtonProto:UpdateChecked()
    -- Keep checked during key PUSHED flash (mouse keeps both after PostClick).
    self:SetChecked(IsButtonCurrent(self) and 1 or 0)
end

function ButtonProto:Update()
    self:UpdateCooldown()
    self:UpdateCount()
    self:UpdateUsable()
    self:UpdateChecked()
end

function ButtonProto:UpdateHotkey()
    local cfg = Bar_GetConfig(self.bar)
    if not cfg or cfg.show_hotkey == false then
        self.hotkey:SetText("")
        self.hotkeyBound = false
        self.hotkeyDotEligible = false
        self.hotkey:Hide()
        return
    end

    if addon.ApplyHotkeyTypography then
        addon.ApplyHotkeyTypography(self.hotkey)
    end

    local key = GetBindingKey("CLICK " .. self:GetName() .. ":LeftButton")
    if key then
        self.hotkeyBound = true
        self.hotkeyDotEligible = false
        self.hotkey:SetText(LibKeyBound and LibKeyBound:ToShortKey(key) or "")
        ApplyBoundHotkeyColor(self.hotkey)
        self.hotkey:Show()
    else
        self.hotkeyBound = false
        self.hotkeyDotEligible = IsRangeDotEnabled() and true or false
        self.hotkey:SetText(self.hotkeyDotEligible and RANGE_INDICATOR or "")
        self.hotkey:Hide()
    end
end

-- Button script handlers (shared, not per-button closures)

local function Button_OnDragStart(self)
    self._extrabarFromMouse = nil
    OnDragStart(self)
end

-- Click-drop + suppress cast; SetChecked(0) like PetActionButton (stops toggle stick).
local function Button_PreClick(self)
    self:SetChecked(0)
    local placed = AssignFromCursor(self)
    local justPlaced = lastAssignTime[self] and (GetTime() - lastAssignTime[self]) < 0.1
    if (placed or justPlaced) and not InCombatLockdown() then
        Secure.SetType1(self, nil)
        self._extrabarRestoreType = true
    end
end

local function Button_PostClick(self)
    if self._extrabarRestoreType and not InCombatLockdown() then
        self._extrabarRestoreType = nil
        local data = self:GetSlotData()
        if data then Secure.SetType1(self, SecureTypeFor(data)) end
    end
    self:UpdateChecked()
end

local function Button_OnLeave()
    GameTooltip:Hide()
end

-- ============================================================================
-- Update engine — event-driven repaint coalesced per frame; OnUpdate only while
-- dirty or range-polling (idle cost ~0)
-- ============================================================================

local RANGE_POLL_INTERVAL = 0.2

local function Engine_OnUpdate(self, elapsed)
    local bar = self.bar
    if bar.dirty then
        bar.dirty = nil
        bar:RefreshAllStates()
    end
    if bar.rangePolling then
        self.rangeElapsed = self.rangeElapsed + elapsed
        if self.rangeElapsed >= RANGE_POLL_INTERVAL then
            self.rangeElapsed = 0
            if bar.container and bar.container:IsVisible() then
                for _, button in pairs(bar.buttons) do
                    button:UpdateRange()
                end
            end
        end
    elseif not bar.dirty then
        self:Hide()
    end
end

-- ============================================================================
-- Bar factory
-- ============================================================================

local BarProto = {}
local BarProto_MT = { __index = BarProto }

function BarProto:IsEnabled()
    return addon:IsModuleEnabled(self.id)
end

function BarProto:RequestRefresh()
    self.dirty = true
    self.engine:Show()
end

function BarProto:RefreshAllStates()
    if not self.container or not self.container:IsVisible() then return end
    for _, button in pairs(self.buttons) do
        button:Update()
    end
end

function BarProto:HasRangeContent()
    for _, button in pairs(self.buttons) do
        local t = button:GetAttribute("type1")
        if t == "spell" or t == "item" or t == "macro" then return true end
    end
    return false
end

function BarProto:UpdateRangePolling()
    local active = self.applied and self.container and self.container:IsVisible()
        and UnitExists("target") and self:HasRangeContent()
    self.rangePolling = active or nil
    if active then
        self.engine.rangeElapsed = 0
        self.engine:Show()
    end
end

function BarProto:RefreshHotkeys()
    for _, button in pairs(self.buttons) do
        button:UpdateHotkey()
    end
end

function BarProto:RefreshMacroNames()
    for _, button in pairs(self.buttons) do
        button:UpdateName()
    end
end

function BarProto:ReapplySavedSlots()
    local slots = Bar_GetSlots(self)
    if not slots then return end
    for index, button in pairs(self.buttons) do
        button:SetSlotData(slots[index])
    end
end

function BarProto:ApplyAnchorPosition()
    local widgetConfig = addon.db and addon.db.profile and addon.db.profile.widgets
        and addon.db.profile.widgets[self.id]
    self.anchor:ClearAllPoints()
    if widgetConfig and (widgetConfig.anchor or widgetConfig.posX or widgetConfig.posY) then
        local anchorPoint = widgetConfig.anchor or "CENTER"
        self.anchor:SetPoint(anchorPoint, UIParent, anchorPoint, widgetConfig.posX or 0, widgetConfig.posY or 0)
    else
        local cfg = Bar_GetConfig(self) or {}
        self.anchor:SetPoint("CENTER", UIParent, "CENTER", cfg.x_position or 0, cfg.y_position or 260)
    end
end

function BarProto:CreateAnchor()
    if self.anchor then return self.anchor end

    local width, height = Bar_GetAnchorSize(self)
    -- CreateUIFrame (not bare CreateFrame) registers Editor Mode drag like other widgets.
    local anchor = _G["DragonUI_" .. self.uiFrameName] or addon.CreateUIFrame(width, height, self.uiFrameName)
    anchor:SetSize(width, height)

    self.anchor = anchor
    self:ApplyAnchorPosition()
    anchor:SetScale(1)
    return anchor
end

-- Sibling of editor anchor on UIParent (petbar); never FULLSCREEN or buttons cover menus.
function BarProto:CreateContainer()
    local bar = self
    local container = self.container or _G[self.containerName]
        or CreateFrame("Frame", self.containerName, UIParent)
    container:SetParent(UIParent)
    -- Logical size + SetScale; CENTERed on the scaled anchor (SetAllPoints would defeat SetScale).
    container:ClearAllPoints()
    container:SetSize(Bar_GetContainerSize(self))
    container:SetPoint("CENTER", self.anchor, "CENTER", 0, 0)
    container:SetScale(Bar_GetScale(self))
    container:SetFrameStrata("MEDIUM")
    container:SetFrameLevel(5)
    if not container._extrabarHooked then
        container._extrabarHooked = true
        container:SetScript("OnShow", function()
            bar:RequestRefresh()
            bar:UpdateRangePolling()
        end)
        container:SetScript("OnHide", function()
            bar:UpdateRangePolling()
        end)
    end

    self.container = container
    return container
end

function BarProto:CreateButton(index)
    local name = self.buttonNamePrefix .. index
    -- CheckButton like ActionBarButtonTemplate — same Checked/Pushed texture path as buttons.lua.
    local button = _G[name]
    if not button then
        button = CreateFrame("CheckButton", name, self.container, "SecureActionButtonTemplate")
    end
    setmetatable(button, ButtonProto_MT)
    button.bar = self
    button:SetID(index)
    button:SetParent(self.container)
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

        -- ActionButtonTemplate $parentName; inherited font is only a floor, buttons.macros overrides it.
        local nameFS = button:CreateFontString(name .. "Name", "OVERLAY", "GameFontHighlightSmallOutline")
        nameFS:SetDrawLayer("OVERLAY", 7)
        nameFS:SetJustifyH("CENTER")
        nameFS:SetSize(36, 10)
        nameFS:SetPoint("BOTTOM", button, "BOTTOM", 0, 2)
        button.name = nameFS
        ApplyMacroNameStyle(nameFS)

        -- OVERLAY sublevel 7: above SkinButton's border (also OVERLAY).
        local hotkey = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmallGray")
        hotkey:SetDrawLayer("OVERLAY", 7)
        -- Same corner inset as buttons.lua NormalizeAdditionalHotkeyVisual (TOPRIGHT -2, -3).
        hotkey:SetPoint("TOPRIGHT", button, "TOPRIGHT", -2, -3)
        hotkey:SetJustifyH("RIGHT")
        if addon.ApplyHotkeyTypography then
            addon.ApplyHotkeyTypography(hotkey)
        else
            hotkey:SetFont(HOTKEY_FONT, 12, "OUTLINE")
            hotkey:SetShadowOffset(-1.3, -1.1)
            hotkey:SetShadowColor(0, 0, 0, 1)
        end
        ApplyBoundHotkeyColor(hotkey)
        button.hotkey = hotkey

        button:SetScript("OnDragStart", Button_OnDragStart)
        button:SetScript("OnReceiveDrag", AssignFromCursor)
        HookKeyPushFlash(button)
        button:SetScript("PreClick", Button_PreClick)
        button:SetScript("PostClick", Button_PostClick)
        button:SetScript("OnEnter", SetExtrabarTooltip)
        button:SetScript("OnLeave", Button_OnLeave)

        -- After OnEnter SetScript: MakeButtonBindable HookScript is wiped by a later SetScript.
        if addon.KeyBindingModule then
            addon.KeyBindingModule:MakeButtonBindable(button, "CLICK " .. name .. ":LeftButton",
                self.bindingLabel .. index)
        end
    end

    return button
end

function BarProto:CreateButtons()
    if InCombatLockdown() then
        addon.CombatQueue:Add(self.id .. "_create_buttons", self.CreateButtons, self)
        return
    end

    local size, spacing = Bar_GetSizeAndSpacing(self)
    local columns, _, order, shown = Bar_GetGridLayout(self)
    local step = size + spacing

    for index = 1, self.numButtons do
        local button = self:CreateButton(index)
        button:SetSize(size, size)
        if index <= shown then
            local gridIndex = index - 1
            SetGridButtonPoint(button, self.container, math.floor(gridIndex / columns), gridIndex % columns, order, step)
        end
        self.buttons[index] = button
        button:UpdateGridVisibility()
    end

    if addon.RefreshDarkModeActionButtons then
        addon.RefreshDarkModeActionButtons()
    end
end

function BarProto:ShouldShowEmpty()
    if GetCVar("alwaysShowActionBars") == "1"
        or ALWAYS_SHOW_MULTIBARS == "1" or ALWAYS_SHOW_MULTIBARS == 1 then
        return true
    end
    if SpellBookFrame and SpellBookFrame:IsShown() then
        return true
    end
    return (self.dragGrid or 0) > 0
end

function BarProto:UpdateAllGridVisibility()
    for _, button in pairs(self.buttons) do
        button:UpdateGridVisibility()
    end
end

function BarProto:ShowGrid()
    self.dragGrid = (self.dragGrid or 0) + 1
    self:UpdateAllGridVisibility()
end

function BarProto:HideGrid()
    local n = (self.dragGrid or 0) - 1
    if n < 0 then n = 0 end
    self.dragGrid = n
    self:UpdateAllGridVisibility()
end

-- Sole owner of the container [vehicleui] driver (VehicleMenuBar:IsShown is wrong with artstyle).
local function IsVehicleArtStyle()
    local v = addon.db and addon.db.profile and addon.db.profile.additional
        and addon.db.profile.additional.vehicle
    return v and v.artstyle
end

function BarProto:SetupVehicleVisibility()
    if not self.container then return end
    if InCombatLockdown() then
        addon.CombatQueue:Add(self.id .. "_vehicle_vis", self.SetupVehicleVisibility, self)
        return
    end

    if IsVehicleArtStyle() then
        RegisterStateDriver(self.container, "visibility", "[vehicleui] hide; show")
    else
        UnregisterStateDriver(self.container, "visibility")
        if not (addon.EditorMode and addon.EditorMode:IsActive()) then
            self.container:Show()
            if addon.VisibilityFade then
                addon.VisibilityFade.Update(self.id)
            end
        end
    end
end

function BarProto:ClearVehicleVisibility()
    if not self.container or InCombatLockdown() then return end
    UnregisterStateDriver(self.container, "visibility")
end

-- Alpha-only hover/combat fade (VisibilityFade); layered on the vehicle state driver.
function BarProto:RegisterVisibilityFade()
    local bar = self
    local hoverFrames = { self.container }
    for _, button in pairs(self.buttons) do
        table.insert(hoverFrames, button)
    end

    addon.VisibilityFade.Register(self.id, self.container, {
        dbTable = function() return Bar_GetConfig(bar) end,
        hoverFrames = hoverFrames,
        clickThrough = true,
    })
    addon.VisibilityFade.Update(self.id)
end

-- Editor Mode drags the anchor; container SetAllPoints it (buttons are not anchor children).
function BarProto:UpdateEditorFrameRegistration()
    if addon.EditableFrames and addon.EditableFrames[self.id] and self.anchor then
        addon.EditableFrames[self.id].frame = self.anchor
        local width, height = Bar_GetAnchorSize(self)
        self.anchor:SetSize(width, height)
    end
end

function BarProto:ShowTest()
    if not self.anchor then return end
    self.anchor:Show()
    self.anchor:SetMovable(true)
    self.anchor:EnableMouse(true)
    if self.anchor.editorTexture then self.anchor.editorTexture:Show() end
    if self.anchor.editorText then self.anchor.editorText:Show() end

    -- [vehicleui] driver blocks :Show(); drop it while the editor overlay is active.
    if self.container and not InCombatLockdown() then
        UnregisterStateDriver(self.container, "visibility")
        self.container:Show()
        self.container:SetAlpha(1)
    end
    self:UpdateAllGridVisibility()
end

function BarProto:HideTest()
    if not self.anchor then return end
    self.anchor:SetMovable(false)
    self.anchor:EnableMouse(false)
    if self.anchor.editorTexture then self.anchor.editorTexture:Hide() end
    if self.anchor.editorText then self.anchor.editorText:Hide() end

    if addon.SaveUIFramePosition then
        addon.SaveUIFramePosition(self.anchor, "widgets", self.id)
    end

    self:SetupVehicleVisibility()
    self:UpdateAllGridVisibility()
    if addon.VisibilityFade then
        addon.VisibilityFade.Update(self.id)
    end
end

function BarProto:Apply()
    if self.applied or not self:IsEnabled() then return end

    self.dragGrid = 0
    self:CreateAnchor()
    self:CreateContainer()
    self:CreateButtons()
    self:ReapplySavedSlots()
    self:RefreshHotkeys()

    self.applied = true
    self.initialized = true

    if addon.VisibilityFade then
        self:RegisterVisibilityFade()
    end
    self:SetupVehicleVisibility()
    self:UpdateEditorFrameRegistration()
    self:RequestRefresh()
    self:UpdateRangePolling()
end

function BarProto:Restore()
    if not self.applied then return end

    self.engine:Hide()
    self.dirty = nil
    self.rangePolling = nil
    self:ClearVehicleVisibility()
    if addon.VisibilityFade then
        addon.VisibilityFade.Unregister(self.id)
    end
    if self.container then self.container:Hide() end

    self.applied = false
end

function BarProto:RefreshSystem()
    if InCombatLockdown() then
        addon.CombatQueue:Add(self.id .. "_refresh_system", self.RefreshSystem, self)
        return
    end

    if self.applied then
        if not self:IsEnabled() then
            self:Restore()
        else
            self:RefreshFrame()
            self:ReapplySavedSlots()
            self:RefreshHotkeys()
            self:SetupVehicleVisibility()
            if addon.VisibilityFade then
                addon.VisibilityFade.Update(self.id)
            end
        end
    elseif self:IsEnabled() then
        self:Apply()
    end
end

-- Live layout refresh (options sliders); no teardown — same shape as RefreshPetbarFrame.
function BarProto:RefreshFrame()
    if not self.anchor then return end
    if InCombatLockdown() then
        addon.CombatQueue:Add(self.id .. "_refresh_frame", self.RefreshFrame, self)
        return
    end

    local width, height = Bar_GetAnchorSize(self)
    self.anchor:SetSize(width, height)
    self.anchor:SetScale(1)
    self:ApplyAnchorPosition()

    if self.container then
        self.container:SetParent(UIParent)
        self.container:ClearAllPoints()
        self.container:SetSize(Bar_GetContainerSize(self))
        self.container:SetPoint("CENTER", self.anchor, "CENTER", 0, 0)
        self.container:SetScale(Bar_GetScale(self))
        self.container:SetFrameStrata("MEDIUM")
        self.container:SetFrameLevel(5)
    end

    local size, spacing = Bar_GetSizeAndSpacing(self)
    local columns, _, order, shown = Bar_GetGridLayout(self)
    local step = size + spacing
    for index = 1, self.numButtons do
        local button = self.buttons[index]
        if button then
            button:SetSize(size, size)
            if index <= shown then
                local gridIndex = index - 1
                SetGridButtonPoint(button, self.container, math.floor(gridIndex / columns), gridIndex % columns, order, step)
            end
            button:UpdateGridVisibility()
        end
    end

    self:UpdateEditorFrameRegistration()
end

local function CreateExtraBar(spec)
    local bar = setmetatable({
        id = spec.id,
        uiFrameName = spec.uiFrameName,
        containerName = spec.containerName,
        buttonNamePrefix = spec.buttonNamePrefix,
        bindingLabel = spec.bindingLabel,
        numButtons = spec.numButtons or 12,
        buttons = {},
        dragGrid = 0, -- ACTIONBAR_SHOWGRID counter (spellbook/CVar read live)
        applied = false,
        initialized = false,
        anchor = nil,    -- Editor Mode drag frame only (CreateUIFrame); never parents buttons
        container = nil, -- button parent; sibling of anchor so drag mouse isn't blocked by children
    }, BarProto_MT)

    -- Bindings.xml; Key Bindings UI reads BINDING_NAME_* globals (not AceLocale).
    for i = 1, bar.numButtons do
        _G["BINDING_NAME_CLICK " .. bar.buttonNamePrefix .. i .. ":LeftButton"] = bar.bindingLabel .. i
    end

    bar.engine = CreateFrame("Frame")
    bar.engine:Hide()
    bar.engine.bar = bar
    bar.engine.rangeElapsed = 0
    bar.engine:SetScript("OnUpdate", Engine_OnUpdate)

    if addon.RegisterModule then
        addon:RegisterModule(bar.id, bar, spec.displayName, spec.description)
    end

    table.insert(bars, bar)
    return bar
end

-- ============================================================================
-- extrabar1 instance + public API + events
-- ============================================================================

_G.BINDING_HEADER_DragonUI = "DragonUI"

local ExtraBar1 = CreateExtraBar({
    id = "extrabar1",
    uiFrameName = "ExtraBar1",
    containerName = "DragonUI_ExtraBar1Container",
    buttonNamePrefix = "DragonUI_ExtraBarButton",
    bindingLabel = "DragonUI Extra Bar - Button ",
    numButtons = 12,
    displayName = addon.L["Extra Bar"],
    description = addon.L["A standalone action bar, independent of any class bonus bar"],
})

function addon.RefreshExtrabarSystem()
    ExtraBar1:RefreshSystem()
end

function addon.RefreshExtrabarHotkeys()
    ExtraBar1:RefreshHotkeys()
end

function addon.RefreshExtrabarMacroNames()
    ExtraBar1:RefreshMacroNames()
end

function addon.RefreshExtrabarFrame()
    ExtraBar1:RefreshFrame()
end

local function RequestRefreshAll()
    for _, bar in ipairs(bars) do
        if bar.applied then bar:RequestRefresh() end
    end
end

local function ForAppliedBars(method)
    for _, bar in ipairs(bars) do
        if bar.applied then bar[method](bar) end
    end
end

local function RefreshShapeshiftIcons()
    for _, bar in ipairs(bars) do
        if bar.applied then
            for _, button in pairs(bar.buttons) do
                local data = button:GetSlotData()
                if data and data.type == "spell" then
                    button:UpdateIcon(data)
                end
            end
            bar:RequestRefresh()
        end
    end
end

-- Spellbook / Always Show use MultiActionBar_* (refresh only — CVar/spellbook read live).
-- Drag pickup uses ACTIONBAR_SHOWGRID (dragGrid counter).
local gridHooksInstalled
local function InstallGridHooks()
    if gridHooksInstalled then return end
    gridHooksInstalled = true

    if MultiActionBar_ShowAllGrids then
        hooksecurefunc("MultiActionBar_ShowAllGrids", function()
            ForAppliedBars("UpdateAllGridVisibility")
        end)
    end
    if MultiActionBar_HideAllGrids then
        hooksecurefunc("MultiActionBar_HideAllGrids", function()
            ForAppliedBars("UpdateAllGridVisibility")
        end)
    end

    hooksecurefunc("SetCVar", function(name)
        if name ~= "alwaysShowActionBars" then return end
        ForAppliedBars("UpdateAllGridVisibility")
    end)
end

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
initFrame:RegisterEvent("UPDATE_BINDINGS")
initFrame:RegisterEvent("UPDATE_MACROS")
initFrame:RegisterEvent("SPELL_UPDATE_COOLDOWN")
initFrame:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
initFrame:RegisterEvent("BAG_UPDATE_COOLDOWN")
initFrame:RegisterEvent("BAG_UPDATE")
initFrame:RegisterEvent("ACTIONBAR_UPDATE_STATE")
initFrame:RegisterEvent("ACTIONBAR_UPDATE_USABLE")
initFrame:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
initFrame:RegisterEvent("ACTIONBAR_SHOWGRID")
initFrame:RegisterEvent("ACTIONBAR_HIDEGRID")
initFrame:RegisterEvent("SPELLS_CHANGED")
initFrame:RegisterEvent("COMPANION_UPDATE")
initFrame:RegisterEvent("COMPANION_LEARNED")
initFrame:RegisterEvent("COMPANION_UNLEARNED")
initFrame:RegisterEvent("START_AUTOREPEAT_SPELL")
initFrame:RegisterEvent("STOP_AUTOREPEAT_SPELL")
initFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
initFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
initFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
initFrame:RegisterEvent("UNIT_INVENTORY_CHANGED")
-- 3.3.5a has no SPELL_UPDATE_USABLE; player power events cover oom tint with no target.
initFrame:RegisterEvent("UNIT_MANA")
initFrame:RegisterEvent("UNIT_ENERGY")
initFrame:RegisterEvent("UNIT_RAGE")
initFrame:RegisterEvent("UNIT_RUNIC_POWER")
initFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "DragonUI" then return end
        self.addonLoaded = true
        InstallGridHooks()

        for _, bar in ipairs(bars) do
            local b = bar
            if addon.RegisterEditableFrame then
                addon:RegisterEditableFrame({
                    name = b.id,
                    frame = nil, -- set once the anchor is actually created
                    configPath = {"widgets", b.id},
                    showTest = function() b:ShowTest() end,
                    hideTest = function() b:HideTest() end,
                    editorVisible = function() return b:IsEnabled() end, -- hide editor overlay when module disabled
                })
            end
            if addon.db then
                local refresh = function() b:RefreshSystem() end
                addon.db.RegisterCallback(b, "OnProfileChanged", refresh)
                addon.db.RegisterCallback(b, "OnProfileCopied", refresh)
                addon.db.RegisterCallback(b, "OnProfileReset", refresh)
            end
        end
    elseif event == "PLAYER_LOGIN" and self.addonLoaded then
        for _, bar in ipairs(bars) do
            bar:RefreshSystem()
            bar:SetupVehicleVisibility()
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        InvalidateActionSlotCache()
        InvalidateCompanionIndexCache()
        RequestRefreshAll()
        ForAppliedBars("UpdateAllGridVisibility")
    elseif event == "ACTIONBAR_SHOWGRID" then
        ForAppliedBars("ShowGrid")
    elseif event == "ACTIONBAR_HIDEGRID" then
        ForAppliedBars("HideGrid")
    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        InvalidateActionSlotCache()
        RequestRefreshAll()
    elseif event == "SPELLS_CHANGED" then
        InvalidateBookSlotCache()
        RequestRefreshAll()
    elseif event == "COMPANION_LEARNED" or event == "COMPANION_UNLEARNED" or event == "COMPANION_UPDATE" then
        InvalidateCompanionIndexCache()
        RequestRefreshAll()
    elseif event == "UPDATE_BINDINGS" then
        for _, bar in ipairs(bars) do
            if bar.applied then bar:RefreshHotkeys() end
        end
    elseif event == "UPDATE_MACROS" then
        for _, bar in ipairs(bars) do
            if bar.applied then bar:RefreshMacroNames() end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        RequestRefreshAll()
        for _, bar in ipairs(bars) do
            if bar.applied then bar:UpdateRangePolling() end
        end
    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_SHAPESHIFT_FORMS" then
        RefreshShapeshiftIcons()
    elseif event == "UNIT_INVENTORY_CHANGED" or event == "UNIT_MANA" or event == "UNIT_ENERGY"
        or event == "UNIT_RAGE" or event == "UNIT_RUNIC_POWER" then
        if arg1 == "player" then
            RequestRefreshAll()
        end
    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "ACTIONBAR_UPDATE_COOLDOWN"
        or event == "BAG_UPDATE_COOLDOWN" or event == "BAG_UPDATE"
        or event == "ACTIONBAR_UPDATE_STATE" or event == "ACTIONBAR_UPDATE_USABLE"
        or event == "START_AUTOREPEAT_SPELL" or event == "STOP_AUTOREPEAT_SPELL" then
        RequestRefreshAll()
    end
end)
