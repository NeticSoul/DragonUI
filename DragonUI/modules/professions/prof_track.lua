-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)

local P = addon.Professions
local L = addon.L
local Track = {}
P.Track = Track

-- Forever's Track Recipe; 3.3.5a cannot track recipes, so their reagents are kept per character and listed by the tracker.
local DONE_COLOR, TODO_COLOR = "|cff999999", "|cffffffff"

local function store()
    local char = addon.db and addon.db.char
    if not char then return nil end
    char.trackedRecipes = char.trackedRecipes or {}
    return char.trackedRecipes
end

local function tracker()
    return addon:IsModuleEnabled("questtracker") and addon.ObjectiveTracker or nil
end

local function refreshTracker()
    local OT = tracker()
    if OT and OT.Refresh then OT.Refresh() end
end

local function selectedRecipe()
    if IsTradeSkillLinked() then return nil end
    local index = GetTradeSkillSelectionIndex()
    local name, kind = GetTradeSkillInfo(index)
    if not name or kind == "header" then return nil end
    return index, name
end

local function capture(index, name)
    local reagents = {}
    for i = 1, GetTradeSkillNumReagents(index) do
        local reagent, _, need = GetTradeSkillReagentInfo(index, i)
        reagents[i] = { name = reagent, link = GetTradeSkillReagentItemLink(index, i), need = need or 1 }
    end
    return { name = name, icon = GetTradeSkillIcon(index), link = GetTradeSkillRecipeLink(index),
             skill = (GetTradeSkillLine()), reagents = reagents }
end

function Track.SetTracked(name, on)
    local recipes = store()
    if not recipes or not name then return end
    if on then
        local index, selected = selectedRecipe()
        if selected ~= name then return end
        recipes[name] = capture(index, name)
    else
        recipes[name] = nil
    end
    refreshTracker()
    Track.Refresh()
end

local function untrackMenu(block)
    return { { text = OBJECTIVES_STOP_TRACKING, func = function() Track.SetTracked(block.ref, false) end } }
end

local function recipeIndex(name)
    for i = 1, GetNumTradeSkills() do
        local found, kind = GetTradeSkillInfo(i)
        if found == name and kind ~= "header" then return i end
    end
end

-- Selects and scrolls to a recipe, opening every header when a collapsed one hides it.
local function selectRecipe(name)
    local index = recipeIndex(name)
    if not index then
        ExpandTradeSkillSubClass(0)
        index = recipeIndex(name)
    end
    if not index then return end
    TradeSkillFrame_SetSelection(index)
    TradeSkillFrame_Update()
    local List = P.List
    if not (List and List.data) then return end
    local visible = 0
    for _, button in ipairs(List.rows) do
        if button:IsShown() then visible = visible + 1 end
    end
    for row, data in ipairs(List.data) do
        if data.index == index then
            if row <= List.offset or row > List.offset + visible then List.ScrollTo(row - 3) end
            break
        end
    end
end

local function spellFor(skill)
    local entry = P.Professions.EntryForLine(skill)
    if not (entry and (entry.crafts or entry.craftSpell)) then return nil end
    return (GetSpellInfo(entry.craftSpell or entry.ranks[1]))
end

local function isOpen(recipe)
    return TradeSkillFrame and TradeSkillFrame:IsShown() and not IsTradeSkillLinked()
        and GetTradeSkillLine() == recipe.skill and GetNumTradeSkills() > 0
end

-- With its profession open a click selects the recipe; otherwise the catcher below casts the profession first.
local function onClick(block)
    local recipe = store() and store()[block.ref]
    if not recipe then return end
    if IsModifiedClick("CHATLINK") and ChatEdit_GetActiveWindow() and recipe.link then
        ChatEdit_InsertLink(recipe.link)
    elseif isOpen(recipe) then
        -- The Overview keeps the open profession behind it, so the recipe list is there but not shown.
        if P.Frame.page ~= "crafting" then P.Frame.ShowPage("crafting") end
        selectRecipe(recipe.name)
    elseif InCombatLockdown() then
        UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1, 0.1, 0.1, 1)
    end
end

-- Casting a profession is protected, so the tracker row gets a secure catcher the way the side tabs do.
local catcherIds, nextCatcher = {}, 40
local NO_SHIFT_CAST = { ["shift-type1"] = "none" }

local function onEnter(block)
    local recipe = store() and store()[block.ref]
    local spell = recipe and spellFor(recipe.skill)
    if not spell or InCombatLockdown() or isOpen(recipe) then return end
    local id = catcherIds[block]
    if not id then
        id, nextCatcher = nextCatcher, nextCatcher + 1
        catcherIds[block] = id
    end
    local OT, Catchers = addon.ObjectiveTracker, P.Professions.Catchers
    Catchers.Bind(id, block, spell, {
        onEnter = function() OT.Highlight(block, true) end,
        onLeave = function() OT.Highlight(block, false) end,
        onDown = function(_, button)
            if button == "LeftButton" and not IsModifiedClick("CHATLINK") then
                Track.pending = { skill = recipe.skill, name = recipe.name, at = GetTime() }
            end
        end,
        onUp = function(_, button)
            if button == "RightButton" or IsModifiedClick("CHATLINK") then OT.ClickBlock(block, button) end
        end,
    }, NO_SHIFT_CAST)
    Catchers.ArmFor(block)
end

local function collect(blocks)
    local recipes = store()
    if not recipes or not addon:IsModuleEnabled("professions") then return end
    local names = {}
    for name in pairs(recipes) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        local recipe = recipes[name]
        local lines = {}
        for _, reagent in ipairs(recipe.reagents) do
            local have = GetItemCount(reagent.link or reagent.name) or 0
            local color = have >= reagent.need and DONE_COLOR or TODO_COLOR
            lines[#lines + 1] = { text = string.format("%s%d/%d %s|r", color, have, reagent.need, reagent.name or "") }
        end
        blocks[#blocks + 1] = { kind = "recipe", title = recipe.name, icon = recipe.icon, lines = lines,
                                ref = name, menu = untrackMenu, onClick = onClick, onEnter = onEnter }
    end
end

function Track.Build()
    local Details = P.Details
    local box = addon.ForeverUI.CreateCheckbox(P.Frame.craft, "", function(checked)
        local _, name = selectedRecipe()
        Track.SetTracked(name, checked)
    end, { font = "GameFontHighlightSmall" })
    box:SetSize(26, 26)
    -- Camelot's OverrideArt: the schematic form's bottom-left corner, 17 in and 11 up.
    box:SetPoint("BOTTOMLEFT", Details.card, "BOTTOMLEFT", 17, 11)
    box:SetLabel(L["Track Recipe"])
    box.label:SetTextColor(0.75, 0.75, 0.75)
    box:Hide()
    Track.box = box
end

function Track.Refresh()
    local box = Track.box
    if not box then return end
    local _, name = selectedRecipe()
    local entry = P.Professions.EntryForLine(GetTradeSkillLine())
    -- Runeforging takes no reagents, so there is nothing to gather.
    -- Another addon's card (P.Host) brings its own.
    local show = name ~= nil and tracker() ~= nil and not (entry and entry.key == "Runeforging")
        and not (P.Host and P.Host.Replaces("card"))
    box:SetShownCompat(show)
    if show then box:SetChecked(Track.IsTracked(name)) end
end

function Track.IsTracked(name)
    local recipes = store()
    return recipes ~= nil and name ~= nil and recipes[name] ~= nil
end

-- The recipe a catcher click asked for, selected once its profession has opened.
local function selectPending()
    local want = Track.pending
    if not want or GetTime() - want.at > 5 or IsTradeSkillLinked() or GetTradeSkillLine() ~= want.skill then return end
    Track.pending = nil
    selectRecipe(want.name)
end

P.On("Built", Track.Build)
P.On("Update", function()
    selectPending()
    Track.Refresh()
end)
P.On("Selection", Track.Refresh)
P.On("Hide", function() Track.pending = nil end)

-- Listed from login on, before any profession has been opened.
if addon.ObjectiveTracker and addon.ObjectiveTracker.AddCollector then addon.ObjectiveTracker.AddCollector(collect) end

-- Reagent counts follow the bags; a burst of BAG_UPDATEs collapses into one tracker refresh.
local pending = false
local events = CreateFrame("Frame")
events:RegisterEvent("BAG_UPDATE")
events:SetScript("OnEvent", function()
    local recipes = store()
    if pending or not (recipes and next(recipes)) or not addon:IsModuleEnabled("professions") then return end
    pending = true
    addon:After(0.3, function()
        pending = false
        refreshTracker()
    end)
end)
