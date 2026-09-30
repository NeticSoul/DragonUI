-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local tr = addon.L

local next, select = next, select

local Book = { initialized = false, applied = false }
addon.SpellbookModule = Book

addon:RegisterModule("spellbook", Book, tr["Spellbook"], tr["Learned spells book with categories, search, and filters."],
    { lifecyclePrefix = "Spellbook", loadOnce = true })

-- Category ids double as secure attribute suffixes and as the tab catchers' IDs.
Book.CLASS, Book.GENERAL, Book.PET = 1, 2, 3
Book.CATEGORIES = 3
Book.SLOTS = 54

Book.models, Book.dirty, Book.labels, Book.bound = {}, {}, {}, {}
Book.epoch = 0

function Book.Config()
    return addon:GetModuleConfig("spellbook")
end

function Book.IsOpen()
    return Book.root ~= nil and Book.root:IsShown()
end

function addon.IsSpellbookWindowShown()
    return Book.IsOpen()
end

-- The root and every secure child refuse plain-code changes while this holds.
function Book.Locked()
    return InCombatLockdown()
end

function Book.RefuseInCombat()
    if not Book.Locked() then return false end
    UIErrorsFrame:AddMessage(ERR_NOT_IN_COMBAT, 1.0, 0.1, 0.1, 1.0)
    return true
end

-- Events ------------------------------------------------------------------------------------------

local hub = CreateFrame("Frame")
local listeners = {}

hub:SetScript("OnEvent", function(_, event, ...)
    local list = listeners[event]
    for position = 1, #list do
        list[position](...)
    end
end)

function Book.On(event, handler)
    local list = listeners[event]
    if not list then
        list = {}
        listeners[event] = list
        hub:RegisterEvent(event)
    end
    list[#list + 1] = handler
end

-- Coalesced work: bursts of events collapse into one pass on the next frame ----------------------

local jobs = {}
local ticker = CreateFrame("Frame")
ticker:Hide()

ticker:SetScript("OnUpdate", function(self)
    self:Hide()
    local batch = jobs
    jobs = {}
    if batch.rebuild and next(Book.dirty) and not Book.Locked() then
        -- Closed, only what the key snippets branch on is kept current; opening rebuilds the rest.
        if Book.IsOpen() then Book.Rebuild() else Book.PublishPresence() end
    elseif Book.IsOpen() then
        Book.RefreshVisible(batch)
    end
end)

function Book.Queue(job)
    if not Book.root or (job ~= "rebuild" and not Book.IsOpen()) then return end
    jobs[job] = true
    ticker:Show()
end

function Book.MarkDirty(...)
    for position = 1, select("#", ...) do
        Book.dirty[select(position, ...)] = true
    end
    Book.Queue("rebuild")
end

function Book.MarkAllDirty()
    Book.MarkDirty(Book.CLASS, Book.GENERAL, Book.PET)
end

-- The page reset waits for the rebuild so no click can resolve page 1 while page N is drawn.
function Book.RestartFromFirstPage()
    Book.backToFirstPage = true
    Book.MarkAllDirty()
end

-- Models ------------------------------------------------------------------------------------------

-- What is drawn: the saved choice unless the window had to fall back to one page (FitWindow).
function Book.Wide()
    if Book.shownWide == nil then return not Book.Config().minimized end
    return Book.shownWide
end

function Book.WindowWidth()
    return Book.Wide() and Book.WIDE_W or Book.NARROW_W
end

function Book.PlayerLevel()
    return math.max(UnitLevel("player"), Book.levelHint or 0)
end

function Book.Filters()
    return {
        query = Book.query,
        hidePassives = Book.Config().hidePassives and true or false,
        hideUnlearned = Book.Config().hideUnlearned and true or false,
        allRanks = GetCVarBool("ShowAllSpellRanks") and true or false,
        level = Book.PlayerLevel(),
        raceBit = Book.RaceBit(select(2, UnitRace("player"))),
        trainer = Book.TrainerIndex(select(2, UnitClass("player"))),
    }
end

local function buildModel(cat, filters)
    local spreads = Book.FlowSections(Book.BuildSections(cat, filters), Book.Wide() and 2 or 1, Book.WindowWidth())
    local cardCount = 0
    for _, spread in ipairs(spreads) do
        cardCount = cardCount + #spread.cards
    end
    return { spreads = spreads, total = cardCount }
end

-- Out of combat only; one pass yields both what is drawn and what the secure buttons cast.
function Book.Rebuild()
    local filters = Book.Filters()
    local root = Book.root
    for cat = 1, Book.CATEGORIES do
        if Book.dirty[cat] then
            local exists = Book.CategoryExists(cat)
            Book.models[cat] = exists and buildModel(cat, filters) or nil
            Book.labels[cat] = exists and Book.CategoryLabel(cat) or nil
            Book.Publish(cat)
            Book.dirty[cat] = nil
        end
    end
    Book.stale = false
    for cat, model in pairs(Book.models) do
        root:SetAttribute("page-" .. cat, Book.ClampPage(root:GetAttribute("page-" .. cat), #model.spreads))
    end
    if Book.backToFirstPage then
        Book.backToFirstPage = nil
        root:SetAttribute("page-" .. root:GetAttribute("cat"), 1)
    end
    if not Book.models[root:GetAttribute("cat")] then root:SetAttribute("cat", Book.CLASS) end
    if not Book.models[root:GetAttribute("cat-book")] then root:SetAttribute("cat-book", Book.CLASS) end
    Book.ScanActionBars()
    Book.LayoutTabs()
    Book.ApplySecure()
end

-- Window visibility -------------------------------------------------------------------------------

function Book.WindowShown()
    local root = Book.root
    Book.FlattenCorner()
    if Book.Locked() then
        Book.ScanActionBars()
        Book.Sync(false)
    else
        Book.Refit()
        if next(Book.dirty) then
            Book.Rebuild()
        else
            Book.ScanActionBars()
            Book.Sync(false)
        end
        Book.AdoptSideTab()
        Book.ShowActionGrids()
    end
    PlaySound(root:GetAttribute("cat") == Book.PET and "igAbilityOpen" or "igSpellBookOpen")
    UpdateMicroButtons()
    UIErrorsFrame:Raise()
    Book.StartFlashes()
    Book.SyncLayer()
end

local function insideBook(frame)
    while frame do
        if frame == Book.root then return true end
        frame = frame:GetParent()
    end
    return false
end

function Book.WindowHidden()
    PlaySound(Book.root:GetAttribute("cat") == Book.PET and "igAbilityClose" or "igSpellBookClose")
    Book.CloseRanks()
    Book.ForgetDrawn()
    Book.StopFlashes()
    Book.CloseMenu()
    Book.search:ClearFocus()
    if insideBook(GameTooltip:GetOwner()) then GameTooltip:Hide() end
    Book.ClearMarks()
    Book.SyncLayer()
    Book.HideActionGrids()
    UpdateMicroButtons()
end

-- Combat edges ------------------------------------------------------------------------------------

local function combatStarts()
    if Book.dragging then Book.StopDrag() end
    -- The lock is not on yet during this event, so the menu can still hand its secure rows back.
    Book.CloseRanks()
    Book.CloseMenu()
    Book.search:ClearFocus()
    Book.LiftLayer()
    -- Last moment the secure tables can change before any category is switched to in combat.
    if next(Book.dirty) and not Book.Locked() then Book.Rebuild() end
end

local function combatEnds()
    if next(Book.dirty) then Book.Rebuild() end
    Book.MenuClosed()
    Book.ReclaimBlizzardBook()
    Book.PlaceMicroCatcher()
    Book.SyncLayer()
end

local function contentChanged()
    Book.stale = true
    Book.epoch = Book.epoch + 1
    Book.MarkAllDirty()
end

local function rescale()
    addon:SafeExecute("spellbook", "scale", Book.Refit)
    Book.PlaceMicroCatcher()
end

local function listenToGame()
    Book.On("SPELLS_CHANGED", contentChanged)
    Book.On("LEARNED_SPELL_IN_TAB", function(tab)
        Book.FlagTab(tab)
        contentChanged()
    end)
    Book.On("UNIT_PET", function(unit)
        if unit == "player" then contentChanged() end
    end)
    Book.On("PLAYER_LEVEL_UP", function(level)
        -- UnitLevel can still report the old level while this event is dispatched.
        Book.levelHint = level
        Book.MarkDirty(Book.CLASS, Book.GENERAL)
    end)
    Book.On("PLAYER_TALENT_UPDATE", function() Book.MarkDirty(Book.CLASS, Book.GENERAL) end)
    Book.On("ACTIVE_TALENT_GROUP_CHANGED", function() Book.MarkDirty(Book.CLASS, Book.GENERAL) end)
    Book.On("SPELL_UPDATE_COOLDOWN", function() Book.Queue("cooldown") end)
    Book.On("PET_BAR_UPDATE", function() Book.Queue("autocast") end)
    Book.On("UPDATE_SHAPESHIFT_FORM", function() Book.Queue("icons") end)
    Book.On("CURRENT_SPELL_CAST_CHANGED", function() Book.Queue("selection") end)
    Book.On("TRADE_SKILL_SHOW", function() Book.Queue("selection") end)
    Book.On("TRADE_SKILL_CLOSE", function() Book.Queue("selection") end)
    Book.On("ACTIONBAR_SLOT_CHANGED", function() Book.Queue("glow") end)
    Book.On("PLAYER_MONEY", function() Book.Queue("money") end)
    Book.On("UPDATE_BINDINGS", Book.QueueBindings)
    Book.On("UI_SCALE_CHANGED", rescale)
    Book.On("DISPLAY_SIZE_CHANGED", rescale)
    Book.On("PLAYER_REGEN_DISABLED", combatStarts)
    Book.On("PLAYER_REGEN_ENABLED", combatEnds)
    Book.ListenToBars()
end

-- Lifecycle ---------------------------------------------------------------------------------------

local function apply()
    if Book.applied or not IsLoggedIn() or not addon:IsModuleEnabled("spellbook") then return end
    -- A /reload in combat lands here locked down; secure frames are only configurable afterwards.
    if Book.Locked() then
        addon.CombatQueue:Add("spellbook_apply", apply)
        return
    end
    Book.BuildWindow()
    Book.BuildCards()
    Book.BuildControls()
    Book.BuildSecure()
    Book.InstallAccess()
    listenToGame()
    Book.initialized, Book.applied = true, true
    Book.MarkAllDirty()
end

function addon.ApplySpellbookSystem()
    apply()
end

function addon.RefreshSpellbookSystem()
    apply()
    if not Book.applied then return end
    addon:SafeExecute("spellbook", "profile", function()
        Book.Refit()
        Book.MarkAllDirty()
        if Book.IsOpen() then Book.Rebuild() end
    end)
end

-- Load-once: the registry looks this up but never calls it while applied; disabling needs a reload.
function addon.RestoreSpellbookSystem()
end

function addon.RefreshSpellbookScale(value)
    if type(value) == "number" then Book.Config().scale = value end
    if Book.applied then addon:SafeExecute("spellbook", "scale", Book.Refit) end
end

Book.On("PLAYER_LOGIN", apply)
