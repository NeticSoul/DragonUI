local addon = select(2, ...)
local L = addon.L
addon._dir = "Interface\\AddOns\\DragonUI\\assets\\"
local class = addon._class

-- ============================================================================
-- MAINBARS MODULE FOR DRAGONUI
-- ============================================================================

-- Module state tracking (file scope for cross-function access)
local MainbarsModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    stateDrivers = {},
    frames = {},
    eventFrames = {},
    originalScales = {},
    originalPositions = {},
    originalTextures = {},
    originalVisibility = {},
    actionBarFrames = nil,
    pageDriverInstalled = false,
    pageDriverFrame = nil
}
addon.MainbarsModule = MainbarsModule  -- Expose globally for external access

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("mainbars", MainbarsModule,
        (addon.L and addon.L["Main Bars"]) or "Main Bars",
        (addon.L and addon.L["Main action bars, status bars, scaling and positioning"]) or "Main action bars, status bars, scaling and positioning")
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS (ALWAYS AVAILABLE)
-- ============================================================================

-- Bar sizing constants (used by CalculateFrameSize, ArrangeActionBarButtons, and grid layout)
local ACTION_BUTTON_SIZE = 36  -- Default WoW 3.3.5a action button size
local ACTION_BUTTON_SPACING = 7  -- Spacing between buttons (matches actionbutton_setup)
-- Horizontal padding: 2px each side, matching pretty_actionbar's (2,2) offset.
local DEFAULT_PADDING = 4
-- Vertical padding: 2px bottom + 4px top.  The extra top pixels compensate for
-- the NineSlice BorderArt asymmetry (TOPLEFT y=4 vs BOTTOMRIGHT y=-7) so the
-- button highlight/glow doesn't touch the upper border edge.
local DEFAULT_HEIGHT_PADDING = 6

-- ============================================================================
-- GRID LAYOUT SYSTEM
-- ============================================================================

-- Calculate frame size needed for a given row/column layout
local function CalculateFrameSize(rows, columns, widthPadding, heightPadding, spacing)
    widthPadding = widthPadding or DEFAULT_PADDING
    heightPadding = heightPadding or DEFAULT_HEIGHT_PADDING
    spacing = spacing or ACTION_BUTTON_SPACING
    local width = (ACTION_BUTTON_SIZE * columns) + (spacing * (columns - 1)) + widthPadding
    local height = (ACTION_BUTTON_SIZE * rows) + (spacing * (rows - 1)) + heightPadding
    return width, height
end

-- Arrange action bar buttons in a grid layout
-- buttonPrefix: e.g. "ActionButton", "MultiBarBottomLeftButton"
-- parentFrame: frame to resize (optional)
-- anchorFrame: frame to anchor button positions relative to
-- rows/columns: grid dimensions
-- buttonsShown: number of buttons to display (1-12)
-- widthPadding: total horizontal padding, split equally left/right (default 4 = 2px each side)
-- heightPadding: total vertical padding, split equally top/bottom
function addon.ArrangeActionBarButtons(buttonPrefix, parentFrame, anchorFrame, rows, columns, buttonsShown, widthPadding, heightPadding, spacing)
    if InCombatLockdown() then return end

    buttonsShown = math.max(1, math.min(12, buttonsShown or 12))
    rows = math.max(1, rows or 1)
    columns = math.max(1, columns or 12)
    widthPadding = widthPadding or DEFAULT_PADDING
    heightPadding = heightPadding or DEFAULT_HEIGHT_PADDING
    spacing = spacing or ACTION_BUTTON_SPACING

    -- Horizontal: symmetric (2px each side)
    -- Vertical: asymmetric — 2px bottom, rest on top (compensates NineSlice border overshoot)
    local leftPad = math.floor(widthPadding / 2)
    local bottomPad = 2

    -- Is this the MAIN bar?  Main bar buttons always show (Dragonflight look).
    -- Multibar buttons must NOT be forced visible — Blizzard’s
    -- ActionButton_Update decides their visibility based on showgrid / CVar.
    local isMainBar = (buttonPrefix == "ActionButton")

    for index = 1, NUM_ACTIONBAR_BUTTONS do
        local button = _G[buttonPrefix .. index]
        if button then
            if index <= buttonsShown then
                -- Calculate grid position (0-based)
                local gridIndex = index - 1
                local row = math.floor(gridIndex / columns)
                local col = gridIndex % columns

                local x = leftPad + (col * (ACTION_BUTTON_SIZE + spacing))
                local y = bottomPad + (row * (ACTION_BUTTON_SIZE + spacing))

                button:ClearAllPoints()
                button:SetPoint('BOTTOMLEFT', anchorFrame, 'BOTTOMLEFT', x, y)
                if isMainBar then
                    button:Show()  -- Main bar: always visible
                end
                -- Multibar buttons: do NOT call Show() — let ActionButton_Update handle visibility
            else
                -- Move off-screen and hide (like DragonflightUI)
                button:ClearAllPoints()
                button:SetPoint("CENTER", UIParent, "BOTTOM", 0, -666)
                button:Hide()
            end
        end
    end

    -- Resize parent frame to fit the VISIBLE layout (not max columns)
    if parentFrame and parentFrame.SetSize then
        local effectiveCols = math.min(columns, buttonsShown)
        local width, height = CalculateFrameSize(rows, effectiveCols, widthPadding, heightPadding, spacing)
        parentFrame:SetSize(width, height)
    end
end

local function GetModuleConfig()
    return addon:GetModuleConfig("mainbars")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("mainbars")
end

local mainBarPageByClass = {
    DRUID = '[bonusbar:1,nostealth] 7; [bonusbar:1,stealth] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10;',
    WARRIOR = '[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9;',
    PRIEST = '[bonusbar:1] 7;',
    ROGUE = '[bonusbar:1] 7; [bonusbar:2] 8;',
    DEFAULT = '[bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6;'
}

local function GetMainBarPageCondition()
    local condition = mainBarPageByClass.DEFAULT
    local classCondition = mainBarPageByClass[class]
    if classCondition then
        condition = condition .. ' ' .. classCondition
    end
    return condition .. ' 1'
end

-- Main bar pages are driven through ActionButton actionpage attributes.
-- Keep BonusAction buttons click-through so they never steal mouse clicks
-- when form/stance bars toggle visibility.
local function EnsureBonusButtonsClickThrough()
    if InCombatLockdown() then
        if addon.CombatQueue then
            addon.CombatQueue:Add("mainbars_bonus_buttons_clickthrough", EnsureBonusButtonsClickThrough)
        end
        return
    end

    if BonusActionBarFrame and BonusActionBarFrame.EnableMouse then
        BonusActionBarFrame:EnableMouse(false)
    end

    for i = 1, NUM_ACTIONBAR_BUTTONS do
        local button = _G["BonusActionButton" .. i]
        if button and button.EnableMouse then
            button:EnableMouse(false)
        end
    end
end
-- ============================================================================
-- PET BAR FUNCTION (ALWAYS AVAILABLE)
-- ============================================================================

-- Update pet bar visibility and positioning
function addon.UpdatePetBarVisibility()
    if InCombatLockdown() then
        return
    end

    local petBar = PetActionBarFrame
    if not petBar then
        return
    end

    local petbarModuleEnabled = addon.IsModuleEnabled and addon:IsModuleEnabled("petbar")
    if petbarModuleEnabled then
        -- Petbar module reparents pet buttons to its own secure frame.
        -- Keep Blizzard's PetActionBarFrame non-interactive to avoid
        -- stale invisible hitboxes in its old location.
        petBar:EnableMouse(false)
        petBar:SetAlpha(0)
        petBar:Hide()
        return
    end

    -- Check if player has a pet or is in a vehicle
    local hasPet = UnitExists("pet") and UnitIsVisible("pet")
    local inVehicle = UnitInVehicle("player")
    local hasVehicleActionBar = HasVehicleActionBar and HasVehicleActionBar()

    -- Show pet bar if player has a pet or relevant vehicle controls
    if hasPet or (inVehicle and hasVehicleActionBar) then
        if not petBar:IsShown() then
            petBar:Show()
        end

        -- Ensure proper positioning and scaling
        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if db and db.scale_petbar then
            petBar:SetScale(db.scale_petbar)
        end

        -- Update pet action buttons
        for i = 1, NUM_PET_ACTION_SLOTS do
            local button = _G["PetActionButton" .. i]
            if button then
                button:Show()
            end
        end
    else
        -- Hide pet bar when no pet and not in vehicle
        if petBar:IsShown() then
            petBar:Hide()
        end
    end
end

-- ============================================================================
-- ONLY EXECUTE IF MODULE IS ENABLED
-- ============================================================================
-- ============================================================================
-- ONLY EXECUTE IF MODULE IS ENABLED
-- ============================================================================

-- Check if module is enabled when addon loads
local function InitializeMainbars()
    if not IsModuleEnabled() then
        return -- DO NOTHING if disabled
    end
    
    -- Check if already initialized
    if MainbarsModule.initialized then
        return
    end

    -- ============================================================================
    -- EVERYTHING BELOW ONLY RUNS IF MODULE IS ENABLED
    -- ============================================================================

    -- CORE COMPONENTS
    local config = addon.config;
    local event = addon.package;
    local do_action = addon.functions;
    local select = select;
    local pairs = pairs;
    local ipairs = ipairs;
    local format = string.format;
    local UIParent = UIParent;
    local hooksecurefunc = hooksecurefunc;
    local UnitFactionGroup = UnitFactionGroup;
    local _G = getfenv(0);

    -- constants
    local faction = UnitFactionGroup('player');
    local MainMenuBarMixin = {};
    addon.MainMenuBarMixin = MainMenuBarMixin;  -- Store globally for access
    local pUiMainBar = CreateFrame('Frame', 'pUiMainBar', UIParent, 'MainMenuBarUiTemplate');
    addon.pUiMainBar = pUiMainBar;  -- Store globally for access

    local pUiMainBarArt = CreateFrame('Frame', 'pUiMainBarArt', pUiMainBar);

    -- Main bar page driver owner (bug #251): keep bonus/stance page switching
    -- available even when the vehicle module is disabled.
    local function SetupMainBarPageDriver(mainBar)
        mainBar = mainBar or addon.pUiMainBar or _G.pUiMainBar
        if not mainBar then return end

        if InCombatLockdown() then
            if addon.CombatQueue then
                addon.CombatQueue:Add("mainbars_page_driver", SetupMainBarPageDriver, mainBar)
            end
            return
        end

        -- Init-once behavior: keep the page driver
        -- stable and avoid repeated RegisterStateDriver churn.
        if MainbarsModule.pageDriverInstalled and MainbarsModule.pageDriverFrame == mainBar then
            return
        end

        -- If the driver was previously attached to a different frame, detach it
        -- before reattaching. This path is rare but keeps ownership explicit.
        if MainbarsModule.pageDriverInstalled and MainbarsModule.pageDriverFrame and MainbarsModule.pageDriverFrame ~= mainBar then
            pcall(UnregisterStateDriver, MainbarsModule.pageDriverFrame, 'page')
            MainbarsModule.pageDriverInstalled = false
            MainbarsModule.pageDriverFrame = nil
            MainbarsModule.stateDrivers.page = nil
        end

        for i = 1, 12 do
            local actionButton = _G['ActionButton' .. i]
            if actionButton then
                mainBar:SetFrameRef('ActionButton' .. i, actionButton)
            end
        end

        mainBar:Execute([[
            buttons = newtable()
            for i = 1, 12 do
                local button = self:GetFrameRef('ActionButton'..i)
                if button then
                    table.insert(buttons, button)
                end
            end
        ]])

        mainBar:SetAttribute('_onstate-page', [[
            for i, button in ipairs(buttons) do
                button:SetAttribute('actionpage', tonumber(newstate))
            end
        ]])

        RegisterStateDriver(mainBar, 'page', GetMainBarPageCondition())
        MainbarsModule.stateDrivers.page = { frame = mainBar, state = 'page' }
        MainbarsModule.pageDriverInstalled = true
        MainbarsModule.pageDriverFrame = mainBar
    end

    addon.SetupMainBarPageDriver = SetupMainBarPageDriver

    -- ACTION BAR SYSTEM
    addon.ActionBarFrames = {
        mainbar = nil,
        rightbar = nil,
        leftbar = nil,
        bottombarleft = nil,
        bottombarright = nil,
        xpbar = nil,
        repbar = nil
    }

    -- Set initial scale and properties
    pUiMainBar:SetScale(config.mainbars.scale_actionbar);
    pUiMainBarArt:SetFrameStrata('HIGH');
    pUiMainBarArt:SetFrameLevel(pUiMainBar:GetFrameLevel() + 4);
    pUiMainBarArt:SetAllPoints(pUiMainBar);
    -- CRITICAL: Disable mouse to avoid dead zone on icons
    pUiMainBarArt:EnableMouse(false);

    -- ============================================================================
    -- ALL THE MAINBARS FUNCTIONS (ONLY WHEN ENABLED)
    -- ============================================================================

    -- Use the global UpdateGryphonStyle function
    local UpdateGryphonStyle = addon.UpdateGryphonStyle

    -- ============================================================================
    -- ORIGINAL STATE STORAGE
    -- ============================================================================

    local function StoreOriginalMainbarStates()
        -- Store MainMenuBar state
        if MainMenuBar then
            MainbarsModule.originalStates.MainMenuBar = {
                parent = MainMenuBar:GetParent(),
                scale = MainMenuBar:GetScale(),
                points = {},
                mouseEnabled = MainMenuBar:IsMouseEnabled(),
                movable = MainMenuBar:IsMovable(),
                userPlaced = MainMenuBar:IsUserPlaced()
            }
            for i = 1, MainMenuBar:GetNumPoints() do
                local point, relativeTo, relativePoint, xOfs, yOfs = MainMenuBar:GetPoint(i)
                table.insert(MainbarsModule.originalStates.MainMenuBar.points,
                    {point, relativeTo, relativePoint, xOfs, yOfs})
            end
        end

        -- Store other action bars states
        local bars = {MultiBarRight, MultiBarLeft, MultiBarBottomLeft, MultiBarBottomRight, PetActionBarFrame}
        for _, bar in pairs(bars) do
            if bar then
                local name = bar:GetName()
                MainbarsModule.originalStates[name] = {
                    parent = bar:GetParent(),
                    scale = bar:GetScale(),
                    points = {},
                    mouseEnabled = bar:IsMouseEnabled(),
                    movable = bar:IsMovable(),
                    userPlaced = bar:IsUserPlaced()
                }
                for i = 1, bar:GetNumPoints() do
                    local point, relativeTo, relativePoint, xOfs, yOfs = bar:GetPoint(i)
                    table.insert(MainbarsModule.originalStates[name].points,
                        {point, relativeTo, relativePoint, xOfs, yOfs})
                end
            end
        end
    end

    -- ============================================================================
    -- RESTORE ORIGINAL STATE (When disabled)
    -- ============================================================================

    local function RestoreMainbarsSystem()
        if not MainbarsModule.applied then
            return
        end

        for _, driver in pairs(MainbarsModule.stateDrivers) do
            if driver and driver.frame and driver.state then
                pcall(UnregisterStateDriver, driver.frame, driver.state)
            end
        end
        MainbarsModule.stateDrivers = {}
        MainbarsModule.pageDriverInstalled = false
        MainbarsModule.pageDriverFrame = nil

        -- Hide DragonUI frames
        if MainbarsModule.frames.pUiMainBar then
            MainbarsModule.frames.pUiMainBar:Hide()
            MainbarsModule.frames.pUiMainBar = nil
        end
        if MainbarsModule.frames.pUiMainBarArt then
            MainbarsModule.frames.pUiMainBarArt:Hide()
            MainbarsModule.frames.pUiMainBarArt = nil
        end

        -- Clear ActionBarFrames
        if MainbarsModule.actionBarFrames then
            for name, frame in pairs(MainbarsModule.actionBarFrames) do
                if frame and frame.Hide then
                    frame:Hide()
                end
            end
            MainbarsModule.actionBarFrames = nil
            addon.ActionBarFrames = nil
        end

        -- Restore original states
        for frameName, state in pairs(MainbarsModule.originalStates) do
            local frame = _G[frameName]
            if frame and state then
                frame:SetParent(state.parent or UIParent)
                frame:SetScale(state.scale or 1.0)
                frame:ClearAllPoints()
                if state.points and #state.points > 0 then
                    for _, pointData in pairs(state.points) do
                        frame:SetPoint(pointData[1], pointData[2], pointData[3], pointData[4], pointData[5])
                    end
                else
                    -- Default positioning for action bars
                    if frameName == "MainMenuBar" then
                        frame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
                    elseif frameName == "MultiBarRight" then
                        frame:SetPoint("RIGHT", UIParent, "RIGHT", -6, 0)
                    elseif frameName == "MultiBarLeft" then
                        frame:SetPoint("RIGHT", MultiBarRight, "LEFT", -6, 0)
                    elseif frameName == "MultiBarBottomLeft" then
                        frame:SetPoint("BOTTOMLEFT", ActionButton1, "TOPLEFT", 0, 6)
                    elseif frameName == "MultiBarBottomRight" then
                        frame:SetPoint("BOTTOMLEFT", MultiBarBottomLeftButton1, "TOPLEFT", 0, 6)
                    end
                end
                frame:EnableMouse(state.mouseEnabled ~= false)
                frame:SetMovable(state.movable ~= false)
                frame:SetUserPlaced(state.userPlaced == true)
            end
        end

        -- Show action bars
        local bars = {MainMenuBar, MultiBarRight, MultiBarLeft, MultiBarBottomLeft, MultiBarBottomRight}
        for _, bar in pairs(bars) do
            if bar then
                bar:Show()
            end
        end

        MainbarsModule.originalStates = {}
        MainbarsModule.applied = false

    end

    -- ============================================================================
    -- CORE MAINBAR FUNCTIONS
    -- ============================================================================

   function MainMenuBarMixin:actionbutton_setup()
    -- Phase 3D: Defensive combat guard — secure frame operations must not run in combat
    if InCombatLockdown() then return end
    for _, obj in ipairs({MainMenuBar:GetChildren(), MainMenuBarArtFrame:GetChildren()}) do
        obj:SetParent(pUiMainBar)
    end

    for index = 1, NUM_ACTIONBAR_BUTTONS do
        pUiMainBar:SetFrameRef('ActionButton' .. index, _G['ActionButton' .. index])
    end

    -- Apply SetThreeSlice only if the background is NOT hidden
    local shouldHideBackground = addon.db and addon.db.profile and addon.db.profile.buttons and 
                                addon.db.profile.buttons.hide_main_bar_background
    
    -- Store divider textures for bar-size management
    addon.MainBarDividers = addon.MainBarDividers or {}

    if not shouldHideBackground then
        for index = 1, NUM_ACTIONBAR_BUTTONS - 1 do
            local ActionButtons = _G['ActionButton' .. index]
            do_action.SetThreeSlice(ActionButtons);
            -- Tag divider textures so update_main_bar_background skips them
            if pUiMainBar.divider_top then pUiMainBar.divider_top._isDragonUIDivider = true end
            if pUiMainBar.divider_mid then pUiMainBar.divider_mid._isDragonUIDivider = true end
            if pUiMainBar.divider_bottom then pUiMainBar.divider_bottom._isDragonUIDivider = true end
            -- Store reference to dividers created on pUiMainBar
            addon.MainBarDividers[index] = {
                top = pUiMainBar.divider_top,
                mid = pUiMainBar.divider_mid,
                bottom = pUiMainBar.divider_bottom,
            }
        end
    end

    local initSpacing = (addon.db and addon.db.profile and addon.db.profile.mainbars and addon.db.profile.mainbars.button_spacing) or ACTION_BUTTON_SPACING

    for index = 2, NUM_ACTIONBAR_BUTTONS do
        local ActionButtons = _G['ActionButton' .. index]
        ActionButtons:SetParent(pUiMainBar)
        ActionButtons:SetClearPoint('LEFT', _G['ActionButton' .. (index - 1)], 'RIGHT', initSpacing, 0)

        local BottomLeftButtons = _G['MultiBarBottomLeftButton' .. index]
        BottomLeftButtons:SetClearPoint('LEFT', _G['MultiBarBottomLeftButton' .. (index - 1)], 'RIGHT', initSpacing, 0)

        local BottomRightButtons = _G['MultiBarBottomRightButton' .. index]
        BottomRightButtons:SetClearPoint('LEFT', _G['MultiBarBottomRightButton' .. (index - 1)], 'RIGHT', initSpacing, 0)

        local BonusActionButtons = _G['BonusActionButton' .. index]
        BonusActionButtons:SetClearPoint('LEFT', _G['BonusActionButton' .. (index - 1)], 'RIGHT', initSpacing, 0)
    end
end

    function MainMenuBarMixin:actionbar_art_setup()
        -- setup art frames - FIXED
        MainMenuBarArtFrame:SetParent(pUiMainBarArt)  -- Goes to the art container
        
        -- CRITICAL: Gryphons must go to pUiMainBarArt, NOT pUiMainBar
        for _, art in pairs({MainMenuBarLeftEndCap, MainMenuBarRightEndCap}) do
            art:SetParent(pUiMainBarArt)  -- To the correct art container
            art:SetDrawLayer('OVERLAY', 7)  -- Higher layer than ARTWORK
        end

        -- apply background settings
        self:update_main_bar_background()

        -- apply gryphon styling
        UpdateGryphonStyle()
    end

    function MainMenuBarMixin:update_main_bar_background()
    local alpha = (addon.db and addon.db.profile and addon.db.profile.buttons and
                      addon.db.profile.buttons.hide_main_bar_background) and 0 or 1

    -- This option is for the main bar frame art, not the per-button slot/shadow art.
    -- Button background handling is controlled separately by buttons.only_actionbackground.
    if addon.pUiMainBarArt then addon.pUiMainBarArt:SetAlpha(alpha) end
    if MainMenuBarArtFrame then MainMenuBarArtFrame:SetAlpha(alpha) end
    if MainMenuBarLeftEndCap then MainMenuBarLeftEndCap:SetAlpha(alpha) end
    if MainMenuBarRightEndCap then MainMenuBarRightEndCap:SetAlpha(alpha) end
    if ActionBarUpButton then ActionBarUpButton:SetAlpha(alpha) end
    if ActionBarDownButton then ActionBarDownButton:SetAlpha(alpha) end
    if MainMenuBarPageNumber then MainMenuBarPageNumber:SetAlpha(alpha) end
    if addon.pUiMainBar then
        if addon.pUiMainBar.BorderArt then addon.pUiMainBar.BorderArt:SetAlpha(alpha) end
        if addon.pUiMainBar.Background then addon.pUiMainBar.Background:SetAlpha(alpha) end
    end

    if pUiMainBar then
        -- hide loose textures within pUiMainBar (skip bar-size managed dividers)
        for i = 1, pUiMainBar:GetNumRegions() do
            local region = select(i, pUiMainBar:GetRegions())
            if region and region:GetObjectType() == "Texture" and not region._isDragonUIDivider then
                local texPath = region:GetTexture()
                if texPath and not string.find(texPath, "ICON") then
                    region:SetAlpha(alpha)
                end
            end
        end

        -- hide child frame textures with protection for UI elements
        for i = 1, pUiMainBar:GetNumChildren() do
            local child = select(i, pUiMainBar:GetChildren())
            local name = child and child:GetName()

            -- protect important UI elements from being hidden
            if child and name ~= "pUiMainBarArt" and not string.find(name or "", "ActionButton") and name ~=
                "MultiBarBottomLeft" and name ~= "MultiBarBottomRight" and name ~= "MicroButtonAndBagsBar" and
                not string.find(name or "", "MicroButton") and not string.find(name or "", "Bag") and name ~=
                "CharacterMicroButton" and name ~= "SpellbookMicroButton" and name ~= "TalentMicroButton" and name ~=
                "AchievementMicroButton" and name ~= "bagsFrame" and name ~= "MainMenuBarBackpackButton" and name ~=
                "QuestLogMicroButton" and name ~= "SocialsMicroButton" and name ~= "PVPMicroButton" and name ~=
                "LFGMicroButton" and name ~= "MainMenuMicroButton" and name ~= "HelpMicroButton" and name ~=
                "MainMenuExpBar" and name ~= "ReputationWatchBar" and name ~= "KeyRingButton" then

                for j = 1, child:GetNumRegions() do
                    local region = select(j, child:GetRegions())
                    if region and region:GetObjectType() == "Texture" then
                        region:SetAlpha(alpha)
                    end
                end
            end
        end
    end
end

    function MainMenuBarMixin:actionbar_setup()
        ActionButton1:SetParent(pUiMainBar)
        ActionButton1:SetClearPoint('BOTTOMLEFT', pUiMainBar, 2, 2)

        if config.buttons.pages.show then
            do_action.SetNumPagesButton(ActionBarUpButton, pUiMainBarArt, 'pageuparrow', 8)
            do_action.SetNumPagesButton(ActionBarDownButton, pUiMainBarArt, 'pagedownarrow', -14)

            MainMenuBarPageNumber:SetParent(pUiMainBarArt)
            MainMenuBarPageNumber:SetClearPoint('CENTER', ActionBarDownButton, -1, 12)
            local pagesFont = config.buttons.pages.font
            MainMenuBarPageNumber:SetFont(pagesFont[1], pagesFont[2], pagesFont[3])
            MainMenuBarPageNumber:SetShadowColor(0, 0, 0, 1)
            MainMenuBarPageNumber:SetShadowOffset(1.2, -1.2)
            MainMenuBarPageNumber:SetDrawLayer('OVERLAY', 7)
        else
            ActionBarUpButton:Hide();
            ActionBarDownButton:Hide();
            MainMenuBarPageNumber:Hide();
        end

        MultiBarBottomRight:EnableMouse(false)
        MultiBarRight:SetScale(config.mainbars.scale_rightbar)
        MultiBarLeft:SetScale(config.mainbars.scale_leftbar)
        if MultiBarBottomLeft then
            MultiBarBottomLeft:SetScale(config.mainbars.scale_bottomleft or 0.9)
        end
        if MultiBarBottomRight then
            MultiBarBottomRight:SetScale(config.mainbars.scale_bottomright or 0.9)
        end
    end

    -- Register event to update page number when action bar page changes
    event:RegisterEvents(function()
        MainMenuBarPageNumber:SetText(GetActionBarPage());
        EnsureBonusButtonsClickThrough()
    end,
        'ACTIONBAR_PAGE_CHANGED',
        'UPDATE_BONUS_ACTIONBAR',
        'UPDATE_SHAPESHIFT_FORM'
    );

    -- Helper: position buttons for a left/right bar using chain anchoring.
    -- Position side bar (left/right) buttons in a grid layout using columns.
    -- Uses TOPLEFT origin so button 1 is at top-left (natural reading order).
    -- Columns controls layout: 1 = vertical, 12 = horizontal, anything between = grid.
    local function PositionSideBarButtons(barPrefix, barFrame, containerFrame, count, columns, spacing)
        if not barFrame then return end

        count   = math.max(1, math.min(12, count or 12))
        columns = math.max(1, math.min(12, columns or 1))
        spacing = spacing or ACTION_BUTTON_SPACING

        -- Position visible buttons in a TOPLEFT grid
        -- Side bars are always multibars — do NOT call :Show() on their
        -- buttons.  Blizzard’s ActionButton_Update handles visibility via
        -- the showgrid attribute and the "Always Show Action Bars" CVar.
        for index = 1, NUM_ACTIONBAR_BUTTONS do
            local button = _G[barPrefix .. index]
            if button then
                if index <= count then
                    local gridIndex = index - 1
                    local row = math.floor(gridIndex / columns)
                    local col = gridIndex % columns
                    local x =  col * (ACTION_BUTTON_SIZE + spacing)
                    local y = -(row * (ACTION_BUTTON_SIZE + spacing))
                    button:ClearAllPoints()
                    button:SetPoint('TOPLEFT', barFrame, 'TOPLEFT', x, y)
                    -- NOT calling button:Show() — let ActionButton_Update decide
                else
                    button:ClearAllPoints()
                    button:SetPoint("CENTER", UIParent, "BOTTOM", 0, -666)
                    button:Hide()
                end
            end
        end

        -- Anchor bar frame to container
        if containerFrame then
            barFrame:ClearAllPoints()
            barFrame:SetPoint("TOPLEFT", containerFrame, "TOPLEFT", 0, 0)
        end
    end

    -- Keep secondary bars/buttons from auto-raising on mouse click.
    -- In 3.3.5a, top-level frames promote to the highest frame level when clicked.
    local function StabilizeSecondaryBarLayering()
        if InCombatLockdown() then
            return
        end

        local secondaryBars = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft}
        for _, bar in ipairs(secondaryBars) do
            if bar and bar.SetToplevel then
                bar:SetToplevel(false)
            end
        end

        local secondaryPrefixes = {"MultiBarBottomLeftButton", "MultiBarBottomRightButton", "MultiBarRightButton", "MultiBarLeftButton"}
        for _, prefix in ipairs(secondaryPrefixes) do
            for index = 1, NUM_ACTIONBAR_BUTTONS do
                local button = _G[prefix .. index]
                if button and button.SetToplevel then
                    button:SetToplevel(false)
                end
            end
        end
    end

    function addon.PositionActionBars()
        if InCombatLockdown() then
            return
        end

        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if not db then
            return
        end

        local btnSpacing = db.button_spacing or ACTION_BUTTON_SPACING

        -- Right bar: grid layout using columns (horizontal = 12 cols, vertical = 1 col)
        if MultiBarRight then
            local containerFrame = addon.ActionBarFrames and addon.ActionBarFrames.rightbar
            local rightCfg = db.right or {}
            PositionSideBarButtons("MultiBarRightButton", MultiBarRight, containerFrame,
                rightCfg.buttons_shown or 12, rightCfg.columns or 1, btnSpacing)
        end

        -- Left bar: grid layout using columns
        if MultiBarLeft then
            local containerFrame = addon.ActionBarFrames and addon.ActionBarFrames.leftbar
            local leftCfg = db.left or {}
            PositionSideBarButtons("MultiBarLeftButton", MultiBarLeft, containerFrame,
                leftCfg.buttons_shown or 12, leftCfg.columns or 1, btnSpacing)
        end
    end

    -- Resize a container frame to a new size while keeping the bar anchored to it
    -- in the SAME screen position.  Uses GetCenter() before/after to compensate.
    local function ResizeContainerStable(container, newW, newH)
        if not container then return end
        local oldW, oldH = container:GetWidth(), container:GetHeight()
        if oldW == newW and oldH == newH then return end -- nothing to do

        -- Remember the visual center of the container in screen pixels
        local cx, cy = container:GetCenter()
        if not cx or not cy then
            -- Frame not yet shown; just resize without compensation
            container:SetSize(newW, newH)
            return
        end

        -- Resize
        container:SetSize(newW, newH)

        -- After resize the anchor point is the same but the visual center
        -- shifted because the frame grew/shrank around its anchor.  Read
        -- the NEW center and calculate the delta.
        local cx2, cy2 = container:GetCenter()
        if not cx2 or not cy2 then return end

        local dx = cx - cx2
        local dy = cy - cy2
        if math.abs(dx) < 0.5 and math.abs(dy) < 0.5 then return end

        -- Shift the anchor to cancel the visual movement
        local point, rel, relPoint, px, py = container:GetPoint(1)
        if point then
            container:SetPoint(point, rel, relPoint, (px or 0) + dx, (py or 0) + dy)
        end
    end

    -- Compute container (overlay) size for a bar with the given columns/count.
    -- No padding: buttons fill the container edge-to-edge.
    local function BarContainerSize(cols, count, spacing)
        cols  = math.max(1, cols or 1)
        count = math.max(1, count or 12)
        spacing = spacing or ACTION_BUTTON_SPACING
        local effectiveCols = math.min(cols, count)
        local rows = math.ceil(count / cols)
        local w = effectiveCols * ACTION_BUTTON_SIZE + (effectiveCols - 1) * spacing
        local h = rows * ACTION_BUTTON_SIZE + (rows - 1) * spacing
        return w, h
    end

    -- Resize container (editor overlay) frames to match current bar dimensions.
    -- Called when entering editor mode AND after layout changes so overlays stay in sync.
    -- Overlay sizes are multiplied by the bar's scale so they wrap the visible
    -- (scaled) bar rather than the larger, unscaled logical size.
    -- Uses ResizeContainerStable to avoid shifting bars on screen.
    function addon.UpdateOverlaySizes()
        local db = addon.db and addon.db.profile and addon.db.profile.mainbars
        if not db then return end

        -- Main bar container: match pUiMainBar scaled to visible size
        if addon.ActionBarFrames.mainbar and addon.pUiMainBar then
            local w, h = addon.pUiMainBar:GetSize()
            local scale = db.scale_actionbar or 0.9
            ResizeContainerStable(addon.ActionBarFrames.mainbar, w * scale, h * scale)
        end

        local btnSpacing = db and db.button_spacing or ACTION_BUTTON_SPACING

        -- Right bar container (columns-based grid)
        if addon.ActionBarFrames.rightbar then
            local cfg = db.right or {}
            local w, h = BarContainerSize(cfg.columns or 1, cfg.buttons_shown or 12, btnSpacing)
            local scale = db.scale_rightbar or 0.9
            ResizeContainerStable(addon.ActionBarFrames.rightbar, w * scale, h * scale)
        end

        -- Left bar container (columns-based grid)
        if addon.ActionBarFrames.leftbar then
            local cfg = db.left or {}
            local w, h = BarContainerSize(cfg.columns or 1, cfg.buttons_shown or 12, btnSpacing)
            local scale = db.scale_leftbar or 0.9
            ResizeContainerStable(addon.ActionBarFrames.leftbar, w * scale, h * scale)
        end

        -- Bottom left container
        if addon.ActionBarFrames.bottombarleft then
            local cfg = db.bottom_left or {}
            local w, h = BarContainerSize(cfg.columns or 12, cfg.buttons_shown or 12, btnSpacing)
            local scale = db.scale_bottomleft or 0.9
            ResizeContainerStable(addon.ActionBarFrames.bottombarleft, w * scale, h * scale)
        end

        -- Bottom right container
        if addon.ActionBarFrames.bottombarright then
            local cfg = db.bottom_right or {}
            local w, h = BarContainerSize(cfg.columns or 12, cfg.buttons_shown or 12, btnSpacing)
            local scale = db.scale_bottomright or 0.9
            ResizeContainerStable(addon.ActionBarFrames.bottombarright, w * scale, h * scale)
        end
    end

    -- ============================================================================
    -- XP & REPUTATION BAR SYSTEM
    -- ============================================================================
    -- Dual-style system: "dragonflightui" (custom bars) or "retailui" (atlas reskin)
    -- All state is managed here; options callbacks are exported via addon.*

    -- Helper: get xprepbar config from database
    local function GetXpRepConfig()
        return addon.db and addon.db.profile and addon.db.profile.xprepbar
    end

    -- Helper: get the current style
    local function GetXpBarStyle()
        local cfg = GetXpRepConfig()
        return cfg and cfg.style or "dragonflightui"
    end

    -- Helper: get height for current (or specified) style
    local function GetXpBarHeight(styleOverride)
        local cfg = GetXpRepConfig() or {}
        local s = styleOverride or GetXpBarStyle()
        if s == "retailui" then
            return cfg.bar_height_retailui or 9
        else
            return cfg.bar_height_dfui or 14
        end
    end

    -- Helper: check if XP bar should be visible.
    -- Instead of hardcoding level caps (which break on custom servers),
    -- we check UnitXPMax and UnitXP directly:
    --   • Standard servers at max level: UnitXPMax returns 0  → hidden
    --   • Custom servers at max level:   UnitXPMax returns 1, UnitXP > 1 (e.g. 53/1) → hidden
    --   • Normal leveling:               UnitXPMax returns e.g. 10000, UnitXP < 10000 → shown
    -- We don't rely on MainMenuExpBar:IsShown() because noop kills the
    -- Blizzard events that manage that state.
    local function IsXpBarVisible()
        local maxXP = UnitXPMax("player")
        if not maxXP or maxXP <= 0 then return false end
        local currXP = UnitXP("player") or 0
        return currXP < maxXP
    end

    -- Helper: check if both XP and Rep bars are visible simultaneously
    local function AreBothXpRepBarsVisible()
        if not IsXpBarVisible() then return false end
        local hasWatchedFaction = GetWatchedFactionInfo() ~= nil
        return hasWatchedFaction
    end

    -- Forward declaration so GetDualBarVerticalOffset can reference it before its definition
    local IsWidgetAtDefaultPosition

    -- Helper: get the vertical offset that bars above XP/Rep need when both are visible.
    -- Returns 0 when only one bar (or none) is shown.
    local function GetDualBarVerticalOffset()
        if not AreBothXpRepBarsVisible() then return 0 end
        if not IsWidgetAtDefaultPosition("xpbar") or not IsWidgetAtDefaultPosition("repbar") then return 0 end
        local barH = GetXpBarHeight()
        return barH + 2 -- bar height + 2px gap
    end

    -- Known default positions for BOTTOM-anchored frames.
    -- Used to detect if user moved a frame via editor mode.
    -- IMPORTANT: Keep these in sync with addon.defaults (database.lua → widgets).
    local defaultBottomPositions = {
        mainbar         = { posX = 0,    posY = 22  },
        bottombarleft   = { posX = 0,    posY = 64  },
        bottombarright  = { posX = 0,    posY = 102 },
        petbar          = { posX = 1,    posY = 143 },
        vehicleExit     = { posX = -251, posY = 145 },
        xpbar           = { posX = 1,    posY = 7   },
        repbar          = { posX = 1,    posY = 23  },
    }

    -- Check if a widget is still at its default BOTTOM position (not moved by editor)
    -- Also accepts positions saved with the dual-bar offset baked in, so that
    -- saving via editor mode while both XP+Rep bars are visible doesn't
    -- permanently break offset detection.
    IsWidgetAtDefaultPosition = function(widgetName)
        local known = defaultBottomPositions[widgetName]
        if not known then return false end
        local w = addon.db and addon.db.profile and addon.db.profile.widgets
                  and addon.db.profile.widgets[widgetName]
        if not w then return true end -- No saved position = default
        if w.anchor and w.anchor ~= "BOTTOM" then return false end
        local savedX = w.posX or known.posX
        local savedY = w.posY or known.posY
        -- X must match within ±1
        if math.abs(savedX - known.posX) > 1 then return false end
        -- Y must match base position OR base + dual-bar offset (±1 tolerance)
        if math.abs(savedY - known.posY) <= 1 then return true end
        -- Check against base + max possible offset (bar height + 2px gap)
        local maxOffset = GetXpBarHeight() + 2
        if math.abs(savedY - (known.posY + maxOffset)) <= 1 then return true end
        return false
    end

    -- Export offset function so external modules (stance, petbar) can query it
    addon.GetDualBarVerticalOffset = GetDualBarVerticalOffset
    addon.IsWidgetAtDefaultPosition = IsWidgetAtDefaultPosition
    addon.AreBothXpRepBarsVisible = AreBothXpRepBarsVisible

    -- DragonflightUI custom bar frames (created once, shown/hidden per style)
    local dfXpBar = nil   -- custom XP bar frame
    local dfRepBar = nil  -- custom Rep bar frame

    -- ========== PET BAR SETUP (unchanged) ==========
    function MainMenuBarMixin:statusbar_setup()
        if PetActionBarFrame then
            local db = addon.db and addon.db.profile and addon.db.profile.mainbars
            if db and db.scale_petbar then
                PetActionBarFrame:SetScale(db.scale_petbar)
            elseif config.mainbars.scale_petbar then
                PetActionBarFrame:SetScale(config.mainbars.scale_petbar)
            end

                local petbarModuleEnabled = addon.IsModuleEnabled and addon:IsModuleEnabled("petbar")
                if petbarModuleEnabled then
                    PetActionBarFrame:EnableMouse(false)
                    PetActionBarFrame:SetAlpha(0)
                    PetActionBarFrame:Hide()
                else
                    PetActionBarFrame:EnableMouse(true)
                end
        end

        -- Hide Blizzard XP/Rep text by default (both styles manage their own)
        if MainMenuBarExpText then MainMenuBarExpText:Hide() end
        if ReputationWatchBarText then ReputationWatchBarText:Hide() end
    end

    -- ========== DRAGONFLIGHTUI STYLE: CUSTOM BARS ==========

    -- Create the DragonflightUI-style XP bar (custom StatusBar with rested background)
    local function CreateDragonflightUIXPBar()
        if dfXpBar then return dfXpBar end

        local cfg = GetXpRepConfig() or {}
        local sizeX = cfg.bar_width or 466
        local sizeY = GetXpBarHeight("dragonflightui")

        local f = CreateFrame("Frame", "DragonUI_XPBar", UIParent)
        f:SetSize(sizeX, sizeY)
        f:SetFrameLevel(2)

        -- Background layer
        f.Background = f:CreateTexture(nil, "BACKGROUND")
        f.Background:SetAllPoints()
        f.Background:SetTexture(addon._dir .. "xp\\Background")
        f.Background:SetTexCoord(0, 0.55517578, 0, 1)

        -- Rested XP background bar (shows the TOTAL rested range behind main fill)
        f.RestedBar = CreateFrame("StatusBar", nil, f)
        f.RestedBar:SetPoint("TOPLEFT", 0, 0)
        f.RestedBar:SetPoint("BOTTOMRIGHT", 0, 0)
        f.RestedBar.Texture = f.RestedBar:CreateTexture(nil, "ARTWORK")
        f.RestedBar.Texture:SetTexture(addon._dir .. "xp\\RestedBackground")
        f.RestedBar.Texture:SetAllPoints()
        f.RestedBar.Texture:SetDrawLayer("ARTWORK", 0)
        f.RestedBar:SetStatusBarTexture(f.RestedBar.Texture)
        f.RestedBar:SetFrameLevel(3)
        f.RestedBar:SetAlpha(0.69)

        -- Rested mark tick (small indicator at the end of rested range)
        local markSizeX, markSizeY = 14, sizeY + 6
        f.RestedBarMark = CreateFrame("Frame", nil, f)
        f.RestedBarMark:SetSize(markSizeX, markSizeY)
        f.RestedBarMark.Texture = f.RestedBarMark:CreateTexture(nil, "OVERLAY")
        f.RestedBarMark.Texture:SetTexture(addon._dir .. "uiexperiencebar")
        f.RestedBarMark.Texture:SetTexCoord(1170 / 2048, 1192 / 2048, 201 / 256, 231 / 256)
        f.RestedBarMark.Texture:SetAllPoints()

        -- Main XP progress bar
        f.Bar = CreateFrame("StatusBar", nil, f)
        f.Bar:SetPoint("TOPLEFT", 0, 0)
        f.Bar:SetPoint("BOTTOMRIGHT", 0, 0)
        f.Bar.Texture = f.Bar:CreateTexture(nil, "ARTWORK")
        f.Bar.Texture:SetTexture(addon._dir .. "xp\\Main")
        f.Bar.Texture:SetAllPoints()
        f.Bar:SetStatusBarTexture(f.Bar.Texture)
        f.Bar.Texture:SetDrawLayer("ARTWORK", 1)
        f.Bar:SetFrameLevel(4)
        f.Bar:EnableMouse(true)

        -- Border overlay
        f.Border = f.Bar:CreateTexture(nil, "OVERLAY")
        f.Border:SetTexture(addon._dir .. "xp\\Overlay")
        f.Border:SetTexCoord(0, 0.55517578, 0, 1)
        f.Border:SetPoint("TOPLEFT", 0, 1)
        f.Border:SetPoint("BOTTOMRIGHT", 0, -1)

        -- Text (shown on hover via HIGHLIGHT, or always via OVERLAY)
        f.Text = f.Bar:CreateFontString(nil, "HIGHLIGHT", "SystemFont_Outline_Small")
        f.Text:SetTextColor(1, 1, 1, 1)
        f.Text:SetPoint("CENTER", 0, 1)

        f.TextPercent = f.Bar:CreateFontString(nil, "HIGHLIGHT", "SystemFont_Outline_Small")
        f.TextPercent:SetTextColor(1, 1, 1, 1)
        f.TextPercent:SetPoint("LEFT", f.Text, "RIGHT", 0, 0)

        -- Compatibility: forward right-click to Blizzard XP bar handler
        -- so server-side XP rate dropdowns still work when using custom DFUI bar.
        f.Bar:SetScript("OnMouseDown", function(self, button)
            if button ~= "RightButton" or not MainMenuExpBar then return end
            local handler = MainMenuExpBar:GetScript("OnMouseDown")
            if handler then
                handler(MainMenuExpBar, button)
            end
        end)

        -- Tooltip (borrowed from DragonflightUI)
        f.Bar:SetScript("OnEnter", function(self)
            GameTooltip_AddNewbieTip(self, XPBAR_LABEL, 1.0, 1.0, 1.0, NEWBIE_TOOLTIP_XPBAR, 1)
            GameTooltip.canAddRestStateLine = 1
            ExhaustionToolTipText()
            local currXP = UnitXP("player")
            local maxXP = UnitXPMax("player")
            local pct = (maxXP > 0) and (100 * currXP / maxXP) or 0
            local left = maxXP - currXP
            local leftPct = 100 - pct
            local restedXP = GetXPExhaustion() or 0
            local restedMax = maxXP * 1.5
            local restedPct = (restedMax > 0) and (100 * restedXP / restedMax) or 0
            GameTooltip:AddLine(" ")
            GameTooltip:AddDoubleLine(L["XP: "], format("|cFFFFFFFF%s/%s (%.1f%%)", currXP, maxXP, pct))
            GameTooltip:AddDoubleLine(L["Remaining: "], format("|cFFFFFFFF%s (%.1f%%)", left, leftPct))
            GameTooltip:AddDoubleLine(L["Rested: "], format("|cFFFFFFFF%s (%.1f%%)", restedXP, restedPct))
            GameTooltip:Show()
        end)
        f.Bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

        dfXpBar = f
        return f
    end

    -- Create the DragonflightUI-style Rep bar (custom StatusBar with standing colors)
    local function CreateDragonflightUIRepBar()
        if dfRepBar then return dfRepBar end

        local cfg = GetXpRepConfig() or {}
        local sizeX = cfg.bar_width or 466
        local sizeY = GetXpBarHeight("dragonflightui")

        local f = CreateFrame("Frame", "DragonUI_RepBar", UIParent)
        f:SetSize(sizeX, sizeY)
        f:SetFrameLevel(2)

        -- Background
        f.Background = f:CreateTexture(nil, "BACKGROUND")
        f.Background:SetAllPoints()
        f.Background:SetTexture(addon._dir .. "xp\\Background")
        f.Background:SetTexCoord(0, 0.55517578, 0, 1)

        -- Main rep progress bar
        f.Bar = CreateFrame("StatusBar", nil, f)
        f.Bar:SetPoint("TOPLEFT", 0, 0)
        f.Bar:SetPoint("BOTTOMRIGHT", 0, 0)
        f.Bar.Texture = f.Bar:CreateTexture(nil, "ARTWORK")
        f.Bar.Texture:SetTexture(addon._dir .. "reputation\\Rep")
        f.Bar.Texture:SetAllPoints()
        f.Bar:SetStatusBarTexture(f.Bar.Texture)
        f.Bar:EnableMouse(true)

        -- Border overlay
        f.Border = f.Bar:CreateTexture(nil, "OVERLAY")
        f.Border:SetTexture(addon._dir .. "xp\\Overlay")
        f.Border:SetTexCoord(0, 0.55517578, 0, 1)
        f.Border:SetPoint("TOPLEFT", 0, 1)
        f.Border:SetPoint("BOTTOMRIGHT", 0, -1)

        -- Text (hover by default)
        f.Text = f.Bar:CreateFontString(nil, "HIGHLIGHT", "SystemFont_Outline_Small")
        f.Text:SetTextColor(1, 1, 1, 1)
        f.Text:SetPoint("CENTER", 0, 1)

        -- Click to open reputation panel
        f.Bar:SetScript("OnMouseDown", function(self, button)
            if button == "LeftButton" and not InCombatLockdown() then
                ToggleCharacter("ReputationFrame")
            end
        end)

        -- Tooltip
        f.Bar:SetScript("OnEnter", function(self)
            local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
            if name then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                GameTooltip:AddLine(name, 1, 1, 1)
                local standingLabel = _G["FACTION_STANDING_LABEL" .. standing] or ""
                GameTooltip:AddLine(standingLabel, NORMAL_FONT_COLOR.r, NORMAL_FONT_COLOR.g, NORMAL_FONT_COLOR.b)
                GameTooltip:AddDoubleLine(L["Reputation: "], format("|cFFFFFFFF%s / %s", value - minRep, maxRep - minRep))
                GameTooltip:Show()
            end
        end)
        f.Bar:SetScript("OnLeave", function() GameTooltip:Hide() end)

        dfRepBar = f
        return f
    end

    -- Refresh ExhaustionTick for DragonflightUI style
    -- Extracted so it can be called from ConnectBarsToEditor AND on level-up /
    -- XP-change events (the tick self-hides when fully rested but never
    -- re-shows on its own because OnUpdate gets nilled out).
    local function UpdateDfuiExhaustionTick()
        if not ExhaustionTick or not dfXpBar then return end

        local cfg = GetXpRepConfig() or {}
        local showTick = addon.db and addon.db.profile and addon.db.profile.style
            and addon.db.profile.style.exhaustion_tick
        local exhaustionThreshold = GetXPExhaustion()
        local currXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        if not maxXP or maxXP == 0 then maxXP = 1 end
        local remainingXP = maxXP - currXP
        local isFullyRested = exhaustionThreshold and exhaustionThreshold >= remainingXP

        if showTick and exhaustionThreshold and exhaustionThreshold > 0 and not isFullyRested then
            local barW = cfg.bar_width or 466
            ExhaustionTick:SetParent(dfXpBar)
            ExhaustionTick:SetFrameStrata("HIGH")
            ExhaustionTick:SetFrameLevel(20)
            local tickPos = math.min(((currXP + exhaustionThreshold) / maxXP) * barW, barW)
            tickPos = math.max(tickPos, 0)
            ExhaustionTick:ClearAllPoints()
            ExhaustionTick:SetPoint("CENTER", dfXpBar, "LEFT", tickPos, 0)
            ExhaustionTick:SetScript("OnUpdate", function(self, elapsed)
                if not self.timer then return end
                self.timer = self.timer - elapsed
                if self.timer > 0 then return end
                self.timer = 1
                local et = GetXPExhaustion()
                if not et or et <= 0 then self:Hide() return end
                local cx = UnitXP("player")
                local mx = UnitXPMax("player")
                if not mx or mx == 0 then return end
                if et >= (mx - cx) then self:Hide() return end
                local bw = dfXpBar:GetWidth()
                if not bw or bw == 0 then return end
                local tp = math.min(((cx + et) / mx) * bw, bw)
                tp = math.max(tp, 0)
                self:ClearAllPoints()
                self:SetPoint("CENTER", dfXpBar, "LEFT", tp, 0)
            end)
            ExhaustionTick.timer = 0
            ExhaustionTick:Show()
        else
            ExhaustionTick:Hide()
            ExhaustionTick:SetScript("OnUpdate", nil)
        end
    end

    -- Update the DragonflightUI XP bar values and visuals
    local function UpdateDragonflightUIXPBar()
        if not dfXpBar then return end

        local cfg = GetXpRepConfig() or {}
        local sizeX = cfg.bar_width or 466
        local sizeY = GetXpBarHeight("dragonflightui")
        local markSizeX = 14

        -- Hide the custom XP bar when there's no XP to gain (max level,
        -- XP disabled, etc.).  Uses UnitXPMax — works on any server.
        if not IsXpBarVisible() then
            dfXpBar:Hide()
            return
        end
        dfXpBar:Show()

        local exhaustionStateID = GetRestState()
        local currXP = UnitXP("player")
        local maxXP = UnitXPMax("player")
        if maxXP == 0 then maxXP = 1 end
        local restedXP = GetXPExhaustion() or 0
        local pct = 100 * currXP / maxXP

        -- Set main bar texture based on rested state
        if exhaustionStateID == 1 then
            dfXpBar.Bar.Texture:SetTexture(addon._dir .. "xp\\Rested")
        else
            dfXpBar.Bar.Texture:SetTexture(addon._dir .. "xp\\Main")
        end
        dfXpBar.Bar:SetMinMaxValues(0, maxXP)
        dfXpBar.Bar:SetValue(currXP)

        -- Rested XP background bar
        local showRested = cfg.show_rested_bar ~= false
        if showRested and restedXP and restedXP > 0 then
            dfXpBar.RestedBar:Show()
            dfXpBar.RestedBar:SetMinMaxValues(0, maxXP)
            if (currXP + restedXP) > maxXP then
                dfXpBar.RestedBar:SetValue(maxXP)
                dfXpBar.RestedBarMark:Hide()
            else
                dfXpBar.RestedBar:SetValue(currXP + restedXP)
                local showMark = cfg.show_rested_mark ~= false
                if showMark then
                    dfXpBar.RestedBarMark:Show()
                    dfXpBar.RestedBarMark:ClearAllPoints()
                    dfXpBar.RestedBarMark:SetPoint("LEFT", dfXpBar, "LEFT",
                        (currXP + restedXP) / maxXP * sizeX - markSizeX / 2, 0)
                else
                    dfXpBar.RestedBarMark:Hide()
                end
            end
        else
            dfXpBar.RestedBar:Hide()
            dfXpBar.RestedBarMark:Hide()
        end

        -- Text
        local alwaysText = cfg.always_show_text
        if alwaysText then
            dfXpBar.Text:SetDrawLayer("OVERLAY")
            dfXpBar.TextPercent:SetDrawLayer("OVERLAY")
        else
            dfXpBar.Text:SetDrawLayer("HIGHLIGHT")
            dfXpBar.TextPercent:SetDrawLayer("HIGHLIGHT")
        end

        dfXpBar.Text:SetText(string.format(L["XP: %d/%d"], currXP, maxXP))

        local showPercent = cfg.show_xp_percent ~= false
        if showPercent then
            local restedMax = maxXP * 1.5
            local restedPct = (restedMax > 0) and (100 * restedXP / restedMax) or 0
            local percentText = " = " .. format("%.1f%%", pct)
            if restedPct > 0 then
                percentText = percentText .. " (" .. format("%.1f%%", restedPct) .. " Rested)"
            end
            dfXpBar.TextPercent:SetText(percentText)
            dfXpBar.TextPercent:Show()
            -- Offset main text left by half the percent text width so the combined visual is centered
            local percentWidth = dfXpBar.TextPercent:GetStringWidth() or 0
            dfXpBar.Text:ClearAllPoints()
            dfXpBar.Text:SetPoint("CENTER", 0 - percentWidth / 2, 1)
        else
            dfXpBar.TextPercent:Hide()
            -- Reset to normal centering when percentage is off
            dfXpBar.Text:ClearAllPoints()
            dfXpBar.Text:SetPoint("CENTER", 0, 1)
        end
    end

    -- Update the DragonflightUI Rep bar values and visuals
    local function UpdateDragonflightUIRepBar()
        if not dfRepBar then return end

        local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
        if not name then
            dfRepBar:Hide()
            return
        end
        dfRepBar:Show()

        local cfg = GetXpRepConfig() or {}

        -- Standing-based texture color
        if standing == 1 or standing == 2 then
            dfRepBar.Bar.Texture:SetTexture(addon._dir .. "reputation\\RepRed")
        elseif standing == 3 then
            dfRepBar.Bar.Texture:SetTexture(addon._dir .. "reputation\\RepOrange")
        elseif standing == 4 then
            dfRepBar.Bar.Texture:SetTexture(addon._dir .. "reputation\\RepYellow")
        else
            dfRepBar.Bar.Texture:SetTexture(addon._dir .. "reputation\\RepGreen")
        end

        dfRepBar.Bar:SetMinMaxValues(0, maxRep - minRep)
        dfRepBar.Bar:SetValue(value - minRep)

        -- Text
        local alwaysText = cfg.always_show_text
        if alwaysText then
            dfRepBar.Text:SetDrawLayer("OVERLAY")
        else
            dfRepBar.Text:SetDrawLayer("HIGHLIGHT")
        end
        dfRepBar.Text:SetText(name .. " " .. (value - minRep) .. " / " .. (maxRep - minRep))
    end

    -- ========== RETAILUI STYLE: ATLAS-BASED BLIZZARD RESKIN ==========

    -- Apply RetailUI styling matching the RetailUI reference addon pattern exactly.
    -- Reference: ReplaceBlizzardRepExpBarFrame() in Reference/RetailUI/Modules/ActionBar.lua
    -- Key principles:
    --   1. Replace BACKGROUND textures IN-PLACE (SetTexture + SetTexCoord + SetSize)
    --   2. DON'T change the StatusBar fill texture (leave Blizzard default)
    --   3. Re-use MainMenuXPBarTexture0 as border (noop clears it, we re-apply)
    --   4. Let ExhaustionLevelFillBar handle rested display (just set height)
    local function ApplyRetailUIExpRepBarStyling()
        local cfg = GetXpRepConfig() or {}
        local barW = cfg.bar_width or 466
        local barH = GetXpBarHeight("retailui")
        local ExperienceBarAsset = "Interface\\AddOns\\DragonUI\\Textures\\UI\\ExperienceBar"

        -- === XP BAR ===
        -- NOTE: Do NOT ClearAllPoints here — positioning is handled by
        -- ConnectBarsToEditor() and UpdateBarPositions(). Clearing anchors
        -- here would leave the bar floating at 0,0 between function calls.
        if MainMenuExpBar then
            MainMenuExpBar:SetSize(barW, barH)
            MainMenuExpBar:SetFrameLevel(1)

            -- Replace all BACKGROUND textures in-place with ExperienceBar-Background atlas
            -- Clear original anchors first so our sizing takes effect (2-point anchors override SetSize)
            -- Extend 1px left, 2px right so background fully covers the area inside the border
            local bgFound = false
            for _, region in pairs({MainMenuExpBar:GetRegions()}) do
                if region:GetObjectType() == "Texture" and region:GetDrawLayer() == "BACKGROUND" then
                    if not bgFound then
                        -- Use the first BACKGROUND texture as our single full-width background
                        region:ClearAllPoints()
                        region:SetPoint("TOPLEFT", MainMenuExpBar, "TOPLEFT", -1, 0)
                        region:SetPoint("BOTTOMRIGHT", MainMenuExpBar, "BOTTOMRIGHT", 2, 0)
                        region:SetTexture(ExperienceBarAsset)
                        region:SetTexCoord(0.00088878125 / 2048, 570 / 2048, 20 / 64, 29 / 64)
                        region:SetAlpha(1) -- RemoveBlizzardFrames sets alpha 0, must restore
                        region:Show()
                        bgFound = true
                    else
                        -- Hide extra BACKGROUND textures (only need one)
                        region:Hide()
                    end
                end
            end

            -- Clean up old custom background from previous approach
            if MainMenuExpBar._dragonuiBg then
                MainMenuExpBar._dragonuiBg:Hide()
            end

            -- ExhaustionLevelFillBar: match reference (set height, keep visible for rested display)
            if ExhaustionLevelFillBar then
                ExhaustionLevelFillBar:SetHeight(barH)
                ExhaustionLevelFillBar:Show()
            end

            -- Border: MainMenuXPBarTexture0 (noop.lua clears with SetTexture(nil), we re-apply)
            -- Reference: SetAllPoints first, then override with offset anchors, then set_atlas
            local borderTex = MainMenuXPBarTexture0
            if borderTex then
                borderTex:SetAllPoints(MainMenuExpBar)
                borderTex:SetPoint("TOPLEFT", MainMenuExpBar, "TOPLEFT", -3, 3)
                borderTex:SetPoint("BOTTOMRIGHT", MainMenuExpBar, "BOTTOMRIGHT", 3, -6)
                borderTex:SetDrawLayer("OVERLAY", 1)
                borderTex:SetTexture(ExperienceBarAsset)
                borderTex:SetTexCoord(1 / 2048, 572 / 2048, 1 / 64, 18 / 64)
                borderTex:SetSize(571, 17)
                borderTex:Show()
            end

            -- DON'T change the StatusBar fill texture — reference leaves Blizzard default intact
            -- Clean up old custom fill texture if it exists from previous approach
            if MainMenuExpBar._dragonuiTex then
                MainMenuExpBar._dragonuiTex:Hide()
            end

            -- Clean up old custom rested overlay if it exists from previous approach
            if MainMenuExpBar._restedOverlay then
                MainMenuExpBar._restedOverlay:Hide()
            end

            -- XP text: handle visibility (always show vs hover only)
            if MainMenuBarExpText then
                MainMenuBarExpText:SetParent(MainMenuExpBar)
                MainMenuBarExpText:ClearAllPoints()
                MainMenuBarExpText:SetPoint("CENTER", MainMenuExpBar, "CENTER", 0, 2)

                -- Visibility: OVERLAY = always visible, HIGHLIGHT = hover only
                local alwaysText = cfg.always_show_text
                if alwaysText then
                    MainMenuBarExpText:SetDrawLayer("OVERLAY", 3)
                else
                    MainMenuBarExpText:SetDrawLayer("HIGHLIGHT")
                end
                -- Must Show() to undo the explicit Hide() from init
                MainMenuBarExpText:Show()
            end

            -- Exhaustion tick (safe handler replaces Blizzard's crash-prone OnUpdate)
            if ExhaustionTick then
                local showTick = addon.db and addon.db.profile and addon.db.profile.style
                    and addon.db.profile.style.exhaustion_tick
                local exhaustionThreshold = GetXPExhaustion()
                local currXP = UnitXP("player")
                local maxXP = UnitXPMax("player")
                if not maxXP or maxXP == 0 then maxXP = 1 end

                -- Hide tick if rested XP fills the entire remaining bar
                local remainingXP = maxXP - currXP
                local isFullyRested = exhaustionThreshold and exhaustionThreshold >= remainingXP

                if showTick and exhaustionThreshold and exhaustionThreshold > 0 and not isFullyRested then
                    -- Re-parent to MainMenuExpBar and ensure it renders above everything
                    ExhaustionTick:SetParent(MainMenuExpBar)
                    ExhaustionTick:SetFrameStrata("HIGH")
                    ExhaustionTick:SetFrameLevel(20)
                    -- Position immediately
                    local tickPos = math.min(((currXP + exhaustionThreshold) / maxXP) * barW, barW)
                    tickPos = math.max(tickPos, 0)
                    ExhaustionTick:ClearAllPoints()
                    ExhaustionTick:SetPoint("CENTER", MainMenuExpBar, "LEFT", tickPos, 0)
                    -- Install a nil-safe OnUpdate for continuous tracking
                    ExhaustionTick:SetScript("OnUpdate", function(self, elapsed)
                        if not self.timer then return end
                        self.timer = self.timer - elapsed
                        if self.timer > 0 then return end
                        self.timer = 1
                        local et = GetXPExhaustion()
                        if not et or et <= 0 then
                            self:Hide()
                            return
                        end
                        local cx = UnitXP("player")
                        local mx = UnitXPMax("player")
                        if not mx or mx == 0 then return end
                        -- Hide if fully rested
                        if et >= (mx - cx) then
                            self:Hide()
                            return
                        end
                        local bw = MainMenuExpBar:GetWidth()
                        if not bw or bw == 0 then return end
                        local tp = math.min(((cx + et) / mx) * bw, bw)
                        tp = math.max(tp, 0)
                        self:ClearAllPoints()
                        self:SetPoint("CENTER", MainMenuExpBar, "LEFT", tp, 0)
                    end)
                    ExhaustionTick.timer = 0
                    ExhaustionTick:Show()
                else
                    ExhaustionTick:Hide()
                    ExhaustionTick:SetScript("OnUpdate", nil)
                end
            end

            -- Hide the status overlay if it was created before (cleanup from old code)
            if MainMenuExpBar.status then
                MainMenuExpBar.status:Hide()
            end

            -- Explicitly set XP bar values: noop kills Blizzard's MainMenuBar
            -- events, so MainMenuExpBar_Update() never runs automatically.
            -- Without this the StatusBar fill is empty (0/0).
            local currXP = UnitXP("player")
            local maxXP = UnitXPMax("player")
            if maxXP and maxXP > 0 then
                MainMenuExpBar:SetMinMaxValues(math.min(0, currXP), maxXP)
                MainMenuExpBar:SetValue(currXP)
            end

            MainMenuExpBar:Show()
        end

        -- === REP BAR ===
        -- Reference: ReplaceBlizzardRepExpBarFrame — rep bar section
        -- NOTE: Do NOT ClearAllPoints here — positioning handled by UpdateBarPositions()
        if ReputationWatchBar and ReputationWatchStatusBar then
            ReputationWatchBar:SetSize(barW, barH)
            ReputationWatchBar:SetFrameLevel(1)
            ReputationWatchStatusBar:SetAllPoints(ReputationWatchBar)
            ReputationWatchStatusBar:SetSize(barW, barH)
            -- Enable mouse on the StatusBar so HIGHLIGHT draw layer and OnEnter work.
            -- The StatusBar covers the full area via SetAllPoints, so it receives
            -- mouse events instead of the parent ReputationWatchBar.
            ReputationWatchStatusBar:EnableMouse(true)
            -- DON'T change rep StatusBar fill texture — leave Blizzard default

            -- Background: use named background texture per reference pattern
            -- Reference: _G[repStatusBar:GetName() .. "Background"]
            -- Extend 1px left, 2px right so background fully covers the area inside the border
            local repBgTex = ReputationWatchStatusBarBackground
            if repBgTex then
                repBgTex:ClearAllPoints()
                repBgTex:SetPoint("TOPLEFT", ReputationWatchStatusBar, "TOPLEFT", -1, 0)
                repBgTex:SetPoint("BOTTOMRIGHT", ReputationWatchStatusBar, "BOTTOMRIGHT", 2, 0)
                repBgTex:SetTexture(ExperienceBarAsset)
                repBgTex:SetTexCoord(0.00088878125 / 2048, 570 / 2048, 20 / 64, 29 / 64)
                repBgTex:SetAlpha(1) -- RemoveBlizzardFrames may set alpha 0, must restore
            end

            -- Border: ReputationXPBarTexture0 (noop.lua clears, we re-apply)
            local repBorder = ReputationXPBarTexture0
            if repBorder then
                repBorder:SetAllPoints(ReputationWatchStatusBar)
                repBorder:SetPoint("TOPLEFT", ReputationWatchStatusBar, "TOPLEFT", -3, 2)
                repBorder:SetPoint("BOTTOMRIGHT", ReputationWatchStatusBar, "BOTTOMRIGHT", 3, -7)
                repBorder:SetDrawLayer("OVERLAY", 1)
                repBorder:SetTexture(ExperienceBarAsset)
                repBorder:SetTexCoord(1 / 2048, 572 / 2048, 1 / 64, 18 / 64)
                repBorder:SetSize(571, 17)
                repBorder:Show()
            end

            -- Border: ReputationWatchBarTexture0 (noop.lua clears, we re-apply)
            local repBorder2 = ReputationWatchBarTexture0
            if repBorder2 then
                repBorder2:SetAllPoints(ReputationWatchStatusBar)
                repBorder2:SetPoint("TOPLEFT", ReputationWatchStatusBar, "TOPLEFT", -3, 2)
                repBorder2:SetPoint("BOTTOMRIGHT", ReputationWatchStatusBar, "BOTTOMRIGHT", 3, -7)
                repBorder2:SetDrawLayer("OVERLAY", 1)
                repBorder2:SetTexture(ExperienceBarAsset)
                repBorder2:SetTexCoord(1 / 2048, 572 / 2048, 1 / 64, 18 / 64)
                repBorder2:SetSize(571, 17)
                repBorder2:Show()
            end

            -- Hide the status overlay if it was created before (cleanup from old code)
            if ReputationWatchStatusBar.status then
                ReputationWatchStatusBar.status:Hide()
            end

            -- Explicitly set rep bar values: noop kills Blizzard's MainMenuBar
            -- events, so ReputationWatchBar_Update() never runs automatically.
            local fName, fStanding, fMin, fMax, fValue = GetWatchedFactionInfo()
            if fName and fMax and fMax > fMin then
                ReputationWatchStatusBar:SetMinMaxValues(fMin, fMax)
                ReputationWatchStatusBar:SetValue(fValue)
            end

            -- Rep text: handle visibility (always show vs hover only)
            if ReputationWatchStatusBarText then
                ReputationWatchStatusBarText:SetParent(ReputationWatchStatusBar)
                ReputationWatchStatusBarText:ClearAllPoints()
                ReputationWatchStatusBarText:SetPoint("CENTER", ReputationWatchStatusBar, "CENTER", 0, 1)
                local alwaysText = cfg.always_show_text
                if alwaysText then
                    ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 3)
                    -- Set the text explicitly with faction name for "always show" mode
                    local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
                    if name then
                        local current = value - minRep
                        local maximum = maxRep - minRep
                        ReputationWatchStatusBarText:SetText(format("%s: %d / %d", name, current, maximum))
                    end
                else
                    ReputationWatchStatusBarText:SetDrawLayer("HIGHLIGHT")
                end
                ReputationWatchStatusBarText:Show()
            end
        end

        -- Re-apply dark mode tint — SetTexture() above resets vertex colors
        if addon.RefreshDarkModeXPRepBars then
            addon.RefreshDarkModeXPRepBars()
        end
    end

    -- ========== SHARED: CONNECT BARS TO EDITOR & POSITIONING ==========

    -- Connect bars to their individual editor frames (XP and Rep are separate)
    local function ConnectBarsToEditor()
        if not addon.ActionBarFrames.xpbar or not addon.ActionBarFrames.repbar then return end

        local cfg = GetXpRepConfig() or {}
        local style = GetXpBarStyle()

        if style == "dragonflightui" then
            -- Hide Blizzard bars, show custom bars
            if MainMenuExpBar then
                MainMenuExpBar:SetParent(UIParent)
                MainMenuExpBar:ClearAllPoints()
                MainMenuExpBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, -500)
                MainMenuExpBar:SetAlpha(0)
            end
            if ReputationWatchBar then
                ReputationWatchBar:SetParent(UIParent)
                ReputationWatchBar:ClearAllPoints()
                ReputationWatchBar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, -500)
                ReputationWatchBar:SetAlpha(0)
            end
            if ExhaustionTick then
                -- In DFUI, ExhaustionTick is managed by the tick logic below (if enabled)
                -- Always hide initially; the style-specific tick code will show if needed
                ExhaustionTick:Hide()
                ExhaustionTick:SetScript("OnUpdate", nil)
            end
            if ExhaustionLevelFillBar then ExhaustionLevelFillBar:Hide() end

            -- Create and parent custom bars to their own editor frames
            local xpBar = CreateDragonflightUIXPBar()
            local repBar = CreateDragonflightUIRepBar()

            -- Store references on addon table so dark mode can find them reliably
            addon.DfuiXpBar = xpBar
            addon.DfuiRepBar = repBar

            xpBar:SetParent(addon.ActionBarFrames.xpbar)
            xpBar:SetScale(cfg.expbar_scale or 1.0)
            xpBar:SetFrameStrata("MEDIUM")

            repBar:SetParent(addon.ActionBarFrames.repbar)
            repBar:SetScale(cfg.repbar_scale or 1.0)
            repBar:SetFrameStrata("MEDIUM")

            -- Exhaustion tick for DragonflightUI: delegated to UpdateDfuiExhaustionTick()
            UpdateDfuiExhaustionTick()

            -- Re-apply dark mode tint to newly created bar borders
            if addon.RefreshDarkModeXPRepBars then
                addon.RefreshDarkModeXPRepBars()
            end

        else -- retailui
            -- Hide custom bars if they exist
            if dfXpBar then dfXpBar:Hide() end
            if dfRepBar then dfRepBar:Hide() end

            -- Parent Blizzard XP bar to its own editor frame
            if MainMenuExpBar then
                MainMenuExpBar:SetAlpha(1)
                MainMenuExpBar:ClearAllPoints()
                MainMenuExpBar:SetParent(addon.ActionBarFrames.xpbar)
                MainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.xpbar, "CENTER", 0, 0)
                MainMenuExpBar:SetScale(cfg.expbar_scale or 1.0)
                MainMenuExpBar:SetFrameStrata("MEDIUM")
                MainMenuExpBar:SetFrameLevel(1)
                MainMenuExpBar:Show()
            end
            -- Parent Blizzard Rep bar to its own editor frame
            if ReputationWatchBar then
                ReputationWatchBar:SetAlpha(1)
                ReputationWatchBar:ClearAllPoints()
                ReputationWatchBar:SetParent(addon.ActionBarFrames.repbar)
                ReputationWatchBar:SetPoint("CENTER", addon.ActionBarFrames.repbar, "CENTER", 0, 0)
                ReputationWatchBar:SetScale(cfg.repbar_scale or 1.0)
                ReputationWatchBar:SetFrameStrata("MEDIUM")
                ReputationWatchBar:SetFrameLevel(1)
            end

            -- Re-apply styling since noop may have cleared textures
            ApplyRetailUIExpRepBarStyling()
        end
    end

    -- Position bars centered within their individual editor frames
    local function UpdateBarPositions()
        local cfg = GetXpRepConfig() or {}
        local style = GetXpBarStyle()
        local barW = cfg.bar_width or 466
        local barH = GetXpBarHeight()

        -- Resize editor frames to match bar dimensions
        if addon.ActionBarFrames.xpbar then
            addon.ActionBarFrames.xpbar:SetSize(barW, barH)
        end
        if addon.ActionBarFrames.repbar then
            addon.ActionBarFrames.repbar:SetSize(barW, barH)
        end

        if style == "dragonflightui" then
            -- Resize custom bars to current config
            if dfXpBar then
                dfXpBar:SetSize(barW, barH)
                dfXpBar.Background:SetTexCoord(0, barW / 842, 0, 1)
                dfXpBar.Border:SetTexCoord(0, barW / 842, 0, 1)
                dfXpBar:ClearAllPoints()
                dfXpBar:SetPoint("CENTER", addon.ActionBarFrames.xpbar, "CENTER", 0, 0)
            end
            if dfRepBar then
                dfRepBar:SetSize(barW, barH)
                dfRepBar.Background:SetTexCoord(0, barW / 842, 0, 1)
                dfRepBar.Border:SetTexCoord(0, barW / 842, 0, 1)
                dfRepBar:ClearAllPoints()
                dfRepBar:SetPoint("CENTER", addon.ActionBarFrames.repbar, "CENTER", 0, 0)
            end

            -- Update bar values
            UpdateDragonflightUIXPBar()
            UpdateDragonflightUIRepBar()

        else -- retailui
            -- Position Blizzard XP bar centered in its editor frame
            if MainMenuExpBar then
                MainMenuExpBar:ClearAllPoints()
                MainMenuExpBar:SetSize(barW, barH)
                MainMenuExpBar:SetScale(cfg.expbar_scale or 1.0)
                MainMenuExpBar:SetPoint("CENTER", addon.ActionBarFrames.xpbar, "CENTER", 0, 0)
            end

            -- Position Blizzard Rep bar centered in its editor frame
            if ReputationWatchBar then
                ReputationWatchBar:ClearAllPoints()
                ReputationWatchBar:SetSize(barW, barH)
                ReputationWatchBar:SetScale(cfg.repbar_scale or 1.0)
                ReputationWatchBar:SetPoint("CENTER", addon.ActionBarFrames.repbar, "CENTER", 0, 0)
                if ReputationWatchStatusBar then
                    ReputationWatchStatusBar:SetAllPoints(ReputationWatchBar)
                    ReputationWatchStatusBar:SetSize(barW, barH)
                end
            end
        end

        -- ========== XP BAR VISIBILITY ==========
        -- Show/hide the editor container based on whether the player can
        -- gain XP (UnitXPMax > 0).  This works on any server regardless
        -- of the configured level cap.
        if addon.ActionBarFrames.xpbar then
            if IsXpBarVisible() then
                addon.ActionBarFrames.xpbar:Show()
            else
                addon.ActionBarFrames.xpbar:Hide()
            end
        end
    end

    -- ========== EXPORTED REFRESH / CALLBACK FUNCTIONS ==========
    -- These are called from options.lua and tab_xprepbars.lua

    -- Full refresh of XP/Rep bar system (style, sizing, positioning)
    local function RefreshXpRepBars()
        local style = GetXpBarStyle()
        ConnectBarsToEditor()
        if style == "dragonflightui" then
            UpdateDragonflightUIXPBar()
            UpdateDragonflightUIRepBar()
        else
            ApplyRetailUIExpRepBarStyling()
        end
        UpdateBarPositions()
    end

    -- Export functions for options callbacks
    addon.RefreshXpRepBarPosition = RefreshXpRepBars
    addon.RefreshXpBarPosition = RefreshXpRepBars
    addon.RefreshRepBarPosition = RefreshXpRepBars
    addon.UpdateExhaustionTick = function()
        -- Exhaustion tick works in BOTH styles (RetailUI and DragonflightUI)
        -- Just refresh the full bar system which handles tick visibility
        RefreshXpRepBars()
    end
    addon.RefreshXpRepBars = RefreshXpRepBars

    -- Switch style at runtime (called from options dropdown)
    addon.SetXpBarStyle = function(newStyle)
        if addon.db and addon.db.profile and addon.db.profile.xprepbar then
            addon.db.profile.xprepbar.style = newStyle
        end
        if addon.db and addon.db.profile and addon.db.profile.style then
            addon.db.profile.style.xpbar = newStyle
        end
        -- Full refresh: reconnect, re-style, reposition
        RefreshXpRepBars()
        -- When switching to RetailUI, force Blizzard bar updates to run
        -- so bar values/textures are properly initialized without reload
        if newStyle == "retailui" then
            if MainMenuExpBar_Update then
                MainMenuExpBar_Update()
            end
            if ReputationWatchBar_Update then
                ReputationWatchBar_Update()
            end
            -- Re-apply our styling after Blizzard resets (our hook also runs,
            -- but explicit call ensures correct order)
            ApplyRetailUIExpRepBarStyling()
            UpdateBarPositions()
        end
    end
   -- Specific function to disable MainMenuBarMaxLevelBar
    local function DisableMaxLevelBar()
        if MainMenuBarMaxLevelBar then
            MainMenuBarMaxLevelBar:Hide()
            MainMenuBarMaxLevelBar:EnableMouse(false)
            MainMenuBarMaxLevelBar:SetAlpha(0)
            -- Ensure it never interferes
            MainMenuBarMaxLevelBar:SetFrameLevel(0)
        end
    end

    local function RemoveBlizzardFrames()
        -- Disable MainMenuBarMaxLevelBar immediately
        DisableMaxLevelBar()
        
        local blizzFrames = {MainMenuBarPerformanceBar, MainMenuBarTexture0, MainMenuBarTexture1, MainMenuBarTexture2,
                             MainMenuBarTexture3, MainMenuBarMaxLevelBar, ReputationXPBarTexture1,
                             ReputationXPBarTexture2, ReputationXPBarTexture3, ReputationWatchBarTexture1,
                             ReputationWatchBarTexture2, ReputationWatchBarTexture3, MainMenuXPBarTexture1,
                             MainMenuXPBarTexture2, MainMenuXPBarTexture3, SlidingActionBarTexture0,
                             SlidingActionBarTexture1, BonusActionBarTexture0, BonusActionBarTexture1,
                             ShapeshiftBarLeft, ShapeshiftBarMiddle, ShapeshiftBarRight, PossessBackground1,
                             PossessBackground2}

        for _, frame in pairs(blizzFrames) do
            if frame then
                frame:SetAlpha(0)
                if frame == MainMenuBarMaxLevelBar then
                    frame:EnableMouse(false)
                    frame:Hide()
                    frame:SetFrameLevel(0)
                end
            end
        end
    end

    function MainMenuBarMixin:initialize()
        self:actionbutton_setup();
        self:actionbar_setup();
        self:actionbar_art_setup();
        self:statusbar_setup();
    end

    -- Create action bar container frames (RetailUI pattern)
    -- Uses BarContainerSize() for consistent column-based sizing.
    -- Overlay sizes are multiplied by the bar's scale so they match the
    -- visible (scaled) bar rather than the unscaled logical size.
    local function CreateActionBarFrames()
        local db = addon.db and addon.db.profile and addon.db.profile.mainbars

        -- Main bar - create a NEW container frame scaled to match the visible bar
        local mainScale = db and db.scale_actionbar or 0.9
        addon.ActionBarFrames.mainbar = addon.CreateUIFrame(
            pUiMainBar:GetWidth()  * mainScale,
            pUiMainBar:GetHeight() * mainScale,
            "MainBar")

        local rightCfg = db and db.right or {}
        local leftCfg  = db and db.left or {}
        local blCfg    = db and db.bottom_left or {}
        local brCfg    = db and db.bottom_right or {}
        local btnSpacing = db and db.button_spacing or ACTION_BUTTON_SPACING

        local rW, rH  = BarContainerSize(rightCfg.columns or 1,  rightCfg.buttons_shown or 12, btnSpacing)
        local lW, lH  = BarContainerSize(leftCfg.columns or 1,   leftCfg.buttons_shown or 12, btnSpacing)
        local blW, blH = BarContainerSize(blCfg.columns or 12,   blCfg.buttons_shown or 12, btnSpacing)
        local brW, brH = BarContainerSize(brCfg.columns or 12,   brCfg.buttons_shown or 12, btnSpacing)

        local rScale  = db and db.scale_rightbar     or 0.9
        local lScale  = db and db.scale_leftbar      or 0.9
        local blScale = db and db.scale_bottomleft   or 0.9
        local brScale = db and db.scale_bottomright   or 0.9

        addon.ActionBarFrames.rightbar       = addon.CreateUIFrame(rW * rScale,  rH * rScale,  "RightBar")
        addon.ActionBarFrames.leftbar        = addon.CreateUIFrame(lW * lScale,  lH * lScale,  "LeftBar")
        addon.ActionBarFrames.bottombarleft  = addon.CreateUIFrame(blW * blScale, blH * blScale, "BottomBarLeft")
        addon.ActionBarFrames.bottombarright = addon.CreateUIFrame(brW * brScale, brH * brScale, "BottomBarRight")

        -- Separate XP and Rep bar editor frames (allows independent movement)
        local xpRepWidth = addon.ActionBarFrames.mainbar:GetWidth()
        local cfg = GetXpRepConfig() or {}
        local barH = GetXpBarHeight()
        addon.ActionBarFrames.xpbar = addon.CreateUIFrame(xpRepWidth, barH, "XPBar")
        addon.ActionBarFrames.repbar = addon.CreateUIFrame(xpRepWidth, barH, "RepBar")
    end

    -- Position action bars to their container frames (initialization only - safe during addon load)
    -- Side bars and bottom bars use BOTTOMLEFT so buttons positioned from BOTTOMLEFT
    -- or TOPLEFT align exactly with the container edge.
    local function PositionActionBarsToContainers_Initial()
        -- Position main bar - anchor pUiMainBar to its container (CENTER - has padding/NineSlice)
        if pUiMainBar and addon.ActionBarFrames.mainbar then
            pUiMainBar:SetParent(UIParent)
            pUiMainBar:ClearAllPoints()
            pUiMainBar:SetPoint("CENTER", addon.ActionBarFrames.mainbar, "CENTER")
        end

        -- Position right bar - TOPLEFT matches PositionSideBarButtons grid origin
        if MultiBarRight and addon.ActionBarFrames.rightbar then
            MultiBarRight:SetParent(UIParent)
            MultiBarRight:ClearAllPoints()
            MultiBarRight:SetPoint("TOPLEFT", addon.ActionBarFrames.rightbar, "TOPLEFT", 0, 0)
        end

        -- Position left bar - TOPLEFT matches PositionSideBarButtons grid origin
        if MultiBarLeft and addon.ActionBarFrames.leftbar then
            MultiBarLeft:SetParent(UIParent)
            MultiBarLeft:ClearAllPoints()
            MultiBarLeft:SetPoint("TOPLEFT", addon.ActionBarFrames.leftbar, "TOPLEFT", 0, 0)
        end

        -- Position bottom left bar - CENTER so the bar is visually centered
        -- inside its container regardless of bar scale (0.9 default).
        if MultiBarBottomLeft and addon.ActionBarFrames.bottombarleft then
            MultiBarBottomLeft:SetParent(UIParent)
            MultiBarBottomLeft:ClearAllPoints()
            MultiBarBottomLeft:SetPoint("CENTER", addon.ActionBarFrames.bottombarleft, "CENTER", 0, 0)
        end

        -- Position bottom right bar - CENTER for same reason
        if MultiBarBottomRight and addon.ActionBarFrames.bottombarright then
            MultiBarBottomRight:SetParent(UIParent)
            MultiBarBottomRight:ClearAllPoints()
            MultiBarBottomRight:SetPoint("CENTER", addon.ActionBarFrames.bottombarright, "CENTER", 0, 0)
        end
    end

    -- Position action bars to their container frames
    local function PositionActionBarsToContainers()
        -- Only proceed if not in combat to avoid taint
        if InCombatLockdown() then
            return
        end

        -- Use the initial function for runtime positioning
        PositionActionBarsToContainers_Initial()
    end

    -- Apply saved positions from database (RetailUI pattern)
    local function ApplyActionBarPositions()
        -- CRITICAL: Don't touch secure frames during combat to avoid taint
        -- XP/Rep bars are custom frames and can be positioned any time
        local inCombat = InCombatLockdown()

        if not addon.db or not addon.db.profile or not addon.db.profile.widgets then
            return
        end

        local widgets = addon.db.profile.widgets

        -- Calculate vertical offset when both XP and Rep bars are visible
        local dualBarOffset = GetDualBarVerticalOffset()

        -- Apply mainbar container position (with dual-bar offset if at default)
        -- Skip secure frames (mainbar, action bars) during combat to avoid taint
        if not inCombat and widgets.mainbar and addon.ActionBarFrames.mainbar then
            local config = widgets.mainbar
            if config.anchor then
                local extraY = 0
                if IsWidgetAtDefaultPosition("mainbar") then
                    extraY = dualBarOffset
                end
                addon.ActionBarFrames.mainbar:ClearAllPoints()
                addon.ActionBarFrames.mainbar:SetPoint(config.anchor, config.posX, config.posY + extraY)
            end
        end

        -- Apply other bar positions
        -- Secure frames (action bars) are skipped during combat; custom frames
        -- (xpbar, repbar) are always safe to reposition.
        local secureFrames = {
            rightbar = true,
            leftbar = true,
            bottombarleft = true,
            bottombarright = true,
        }

        local barConfigs = {{
            name = "rightbar",
            frame = addon.ActionBarFrames.rightbar,
            config = widgets.rightbar,
            default = {"RIGHT", -10, -70}
        }, {
            name = "leftbar",
            frame = addon.ActionBarFrames.leftbar,
            config = widgets.leftbar,
            default = {"RIGHT", -45, -70}
        }, {
            name = "bottombarleft",
            frame = addon.ActionBarFrames.bottombarleft,
            config = widgets.bottombarleft,
            default = {"BOTTOM", 0, 120}
        }, {
            name = "bottombarright",
            frame = addon.ActionBarFrames.bottombarright,
            config = widgets.bottombarright,
            default = {"BOTTOM", 0, 160}
        }, -- Separate XP and Rep bar positioning
        {
            name = "xpbar",
            frame = addon.ActionBarFrames.xpbar,
            config = widgets.xpbar,
            default = {"BOTTOM", 0, 7}
        },
        {
            name = "repbar",
            frame = addon.ActionBarFrames.repbar,
            config = widgets.repbar,
            -- When XP bar is hidden (max level, etc.), default to XP bar's slot (Y=7)
            default = {"BOTTOM", 0, IsXpBarVisible() and 23 or 7}
        }}

        -- Frames that should receive the dual-bar vertical offset
        local dualBarOffsetFrames = {
            mainbar = true,  -- already handled above, but listed for clarity
            bottombarleft = true,
            bottombarright = true,
            petbar = true,   -- handled by petbar.lua via addon.UpdatePetbarPosition
            vehicleExit = true, -- handled by vehicle.lua via addon.UpdateVehicleExitPosition
        }
        -- Export so SaveUIFramePosition can strip offset before saving
        addon._dualBarOffsetWidgets = dualBarOffsetFrames

        for _, barData in ipairs(barConfigs) do
            -- Skip secure frames during combat to avoid taint
            if inCombat and secureFrames[barData.name] then
                -- skip this frame
            else
                -- Calculate extra Y for this frame (only if at default position)
                local extraY = 0
                if dualBarOffsetFrames[barData.name] and IsWidgetAtDefaultPosition(barData.name) then
                    extraY = dualBarOffset
                end

                -- When XP bar is hidden (max level on any server, etc.),
                -- drop the rep bar to the XP bar's Y slot so it doesn't
                -- float above the action bar.
                local xpHiddenRepOverrideY = nil
                if barData.name == "repbar" and not IsXpBarVisible() and IsWidgetAtDefaultPosition("repbar") then
                    xpHiddenRepOverrideY = 7  -- XP bar's default Y position
                end

                if barData.frame and barData.config and barData.config.anchor then
                    local config = barData.config
                    local finalY = xpHiddenRepOverrideY or config.posY
                    barData.frame:ClearAllPoints()
                    barData.frame:SetPoint(config.anchor, config.posX, finalY + extraY)
                elseif barData.frame then
                    -- Apply default position
                    local default = barData.default
                    local finalY = xpHiddenRepOverrideY or default[3]
                    barData.frame:ClearAllPoints()
                    barData.frame:SetPoint(default[1], UIParent, default[1], default[2], finalY + extraY)
                end
            end
        end
    end

    -- Notify external modules (stance, multicast, vehicle) that the dual-bar offset may have changed.
    -- Must be defined AFTER ApplyActionBarPositions (Lua local scoping).
    local function NotifyDualBarOffsetChanged()
        -- Re-apply action bar positions (mainbar, bottombarleft, bottombarright)
        ApplyActionBarPositions()
        -- Notify stance bar to update its position
        if addon.UpdateStanceBarPosition then
            addon.UpdateStanceBarPosition()
        end
        -- Notify vehicle exit button to update its position
        if addon.UpdateVehicleExitPosition then
            addon.UpdateVehicleExitPosition()
        end
        -- Notify petbar to update its position
        if addon.UpdatePetbarPosition then
            addon.UpdatePetbarPosition()
        end
    end

    -- Register action bar frames with the centralized system (RetailUI pattern)
    local function RegisterActionBarFrames()
        -- Register all action bar frames
        local frameRegistrations = {{
            name = "mainbar",
            frame = addon.ActionBarFrames.mainbar,
            blizzardFrame = MainMenuBar,
            configPath = {"widgets", "mainbar"}
        }, {
            name = "rightbar",
            frame = addon.ActionBarFrames.rightbar,
            blizzardFrame = MultiBarRight,
            configPath = {"widgets", "rightbar"}
        }, {
            name = "leftbar",
            frame = addon.ActionBarFrames.leftbar,
            blizzardFrame = MultiBarLeft,
            configPath = {"widgets", "leftbar"}
        }, {
            name = "bottombarleft",
            frame = addon.ActionBarFrames.bottombarleft,
            blizzardFrame = MultiBarBottomLeft,
            configPath = {"widgets", "bottombarleft"}
        }, {
            name = "bottombarright",
            frame = addon.ActionBarFrames.bottombarright,
            blizzardFrame = MultiBarBottomRight,
            configPath = {"widgets", "bottombarright"}
        }, -- Separate XP and Rep bar registration with visibility-aware editor
        {
            name = "xpbar",
            frame = addon.ActionBarFrames.xpbar,
            blizzardFrame = nil,
            configPath = {"widgets", "xpbar"},
            editorVisible = function()
                -- Always editable in editor mode, regardless of current XP state
                return true
            end
        },
        {
            name = "repbar",
            frame = addon.ActionBarFrames.repbar,
            blizzardFrame = nil,
            configPath = {"widgets", "repbar"},
            editorVisible = function()
                -- Always editable in editor mode, regardless of current reputation state
                return true
            end
        }}

        for _, registration in ipairs(frameRegistrations) do
            if registration.frame then
                addon:RegisterEditableFrame({
                    name = registration.name,
                    frame = registration.frame,
                    blizzardFrame = registration.blizzardFrame,
                    configPath = registration.configPath,
                    editorVisible = registration.editorVisible,
                    module = addon.MainBars
                })
            end
        end
    end

    -- Hook drag events to ensure action bars follow their containers
    local function SetupActionBarDragHandlers()
        -- Add drag end handlers to reposition action bars
        for name, frame in pairs(addon.ActionBarFrames) do
            -- Exclude bars that don't need repositioning after drag
            if frame and name ~= "mainbar" then
                frame:HookScript("OnDragStop", function(self)
                    -- RetailUI Pattern: Only reposition if not in combat
                    PositionActionBarsToContainers()
                end)
            end
        end
    end

    -- update position for secondary action bars - LEGACY FUNCTION
    function addon.RefreshUpperActionBarsPosition()
        if not MultiBarBottomLeftButton1 or not MultiBarBottomRight then
            return
        end

        -- calculate offset based on background visibility
        local yOffset1, yOffset2
        if addon.db and addon.db.profile.buttons.hide_main_bar_background then
            -- values when background is hidden
            yOffset1 = 45
            yOffset2 = 8
        else
            -- default values when background is visible
            yOffset1 = 48
            yOffset2 = 8
        end
    end

    -- Apply the mainbars system
    local function ApplyMainbarsSystem()
        if MainbarsModule.applied then
            return
        end

        -- CRITICAL: Disable MainMenuBarMaxLevelBar IMMEDIATELY
        if MainMenuBarMaxLevelBar then
            MainMenuBarMaxLevelBar:Hide()
            MainMenuBarMaxLevelBar:EnableMouse(false)
            MainMenuBarMaxLevelBar:SetAlpha(0)
            MainMenuBarMaxLevelBar:SetFrameLevel(0)
        end

        MainMenuBarMixin:initialize()
        addon.pUiMainBar = pUiMainBar
        SetupMainBarPageDriver(pUiMainBar)
        EnsureBonusButtonsClickThrough()

        CreateActionBarFrames()
        ApplyActionBarPositions()
        RegisterActionBarFrames()

        -- Temporarily hide secondary bars to prevent position flash on reload.
        -- They'll be restored in PLAYER_ENTERING_WORLD after final positioning.
        local barsToStabilize = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft}
        for _, bar in ipairs(barsToStabilize) do
            if bar then bar:SetAlpha(0) end
        end

        -- Note: Gryphon frame levels will be set after all positioning is complete

        -- Set up XP/Rep bar system
        ConnectBarsToEditor()

        -- Force Blizzard bar updates so values/textures are properly initialized
        if MainMenuExpBar_Update then MainMenuExpBar_Update() end
        if ReputationWatchBar_Update then ReputationWatchBar_Update() end

        -- Hook MainMenuBarExpText:SetText to append XP percentage in RetailUI mode.
        -- This intercepts ALL text updates (hover, XP gain, etc.) so percentage
        -- is always present regardless of what Blizzard's TextStatusBar system does.
        if MainMenuBarExpText then
            local updatingXpText = false
            hooksecurefunc(MainMenuBarExpText, "SetText", function(self, text)
                if updatingXpText then return end
                if GetXpBarStyle() ~= "retailui" then return end
                local cfg = GetXpRepConfig() or {}
                if cfg.show_xp_percent == false then return end
                if not text or text == "" then return end

                local currXP = UnitXP("player")
                local maxXP = UnitXPMax("player")
                if not maxXP or maxXP == 0 then return end

                local pct = 100 * currXP / maxXP
                local restedXP = GetXPExhaustion() or 0
                local restedMax = maxXP * 1.5
                local restedPct = (restedMax > 0) and (100 * restedXP / restedMax) or 0
                local percentText = format(" (%.1f%%", pct)
                if restedPct > 0 then
                    percentText = percentText .. format(", %.1f%% Rested", restedPct)
                end
                percentText = percentText .. ")"

                updatingXpText = true
                self:SetText(text .. percentText)
                updatingXpText = false
            end)

            -- Prevent Blizzard's TextStatusBar OnLeave from hiding XP text
            -- when "always show text" is enabled. Blizzard calls :Hide() on
            -- the FontString directly, so we must intercept that.
            hooksecurefunc(MainMenuBarExpText, "Hide", function(self)
                if GetXpBarStyle() ~= "retailui" then return end
                local cfg = GetXpRepConfig() or {}
                if cfg.always_show_text then
                    self:Show()
                end
            end)
        end

        -- Same fix for rep bar text: prevent Blizzard's OnLeave from hiding it
        if ReputationWatchStatusBarText then
            hooksecurefunc(ReputationWatchStatusBarText, "Hide", function(self)
                if GetXpBarStyle() ~= "retailui" then return end
                local cfg = GetXpRepConfig() or {}
                if cfg.always_show_text then
                    self:Show()
                end
            end)
        end

        -- Fix RetailUI rep bar hover text: ensure reputation values are shown on hover.
        -- Hook OnEnter on the StatusBar (not the parent ReputationWatchBar) because
        -- the StatusBar covers the full area via SetAllPoints and receives mouse events.
        --
        -- Text format is always "Faction Name: current / max".
        -- When "always show text" is ON, hover does nothing (text is already visible).
        -- When OFF, hover temporarily shows the text via OVERLAY draw layer.
        if ReputationWatchStatusBar then
            ReputationWatchStatusBar:HookScript("OnEnter", function(self)
                if GetXpBarStyle() ~= "retailui" then return end
                if not ReputationWatchStatusBarText then return end
                local cfg = GetXpRepConfig() or {}
                if cfg.always_show_text then return end -- already visible, no change needed
                local name, standing, minRep, maxRep, value = GetWatchedFactionInfo()
                if name then
                    local current = value - minRep
                    local maximum = maxRep - minRep
                    ReputationWatchStatusBarText:SetText(format("%s: %d / %d", name, current, maximum))
                    ReputationWatchStatusBarText:SetDrawLayer("OVERLAY", 3)
                    ReputationWatchStatusBarText:Show()
                end
            end)
            ReputationWatchStatusBar:HookScript("OnLeave", function(self)
                if GetXpBarStyle() ~= "retailui" then return end
                if not ReputationWatchStatusBarText then return end
                local cfg = GetXpRepConfig() or {}
                if cfg.always_show_text then return end -- always visible, no change needed
                ReputationWatchStatusBarText:SetDrawLayer("HIGHLIGHT")
            end)
        end

        -- Hook Blizzard bar updates to re-apply styling and keep positioning in sync
        -- CRITICAL: MainMenuExpBar_Update resets textures — must re-apply our styling
        hooksecurefunc('MainMenuExpBar_Update', function()
            local style = GetXpBarStyle()
            if style == "retailui" then
                ApplyRetailUIExpRepBarStyling()
            end
            UpdateBarPositions()
        end)
        hooksecurefunc('ReputationWatchBar_Update', function()
            local style = GetXpBarStyle()
            if style == "retailui" then
                ApplyRetailUIExpRepBarStyling()
            end
            UpdateBarPositions()
        end)

        -- Position action bars immediately
        PositionActionBarsToContainers_Initial()

        -- Prevent click-only layer promotion on secondary bars.
        StabilizeSecondaryBarLayering()
        
        -- Apply button positioning based on horizontal settings (RetailUI pattern)
        -- This ensures buttons are positioned correctly when horizontal mode is enabled on reload
        if addon.PositionActionBars then
            addon.PositionActionBars()
        elseif addon.PositionActionBarsToContainers then
            addon.PositionActionBarsToContainers()
        end

        -- Set up drag handlers - Execute immediately
        SetupActionBarDragHandlers()

        -- CRITICAL: Ensure gryphons are above all action bars after everything is positioned
        local function EnsureGryphonsOnTop()
            if pUiMainBarArt then
                -- Get the highest frame level from all action bars including containers
                local maxLevel = 1
                local bars = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight, pUiMainBar}
                for _, bar in pairs(bars) do
                    if bar then
                        maxLevel = math.max(maxLevel, bar:GetFrameLevel())
                    end
                end
                
                -- Check container frame levels too
                for _, frame in pairs(addon.ActionBarFrames) do
                    if frame and frame.GetFrameLevel then
                        maxLevel = math.max(maxLevel, frame:GetFrameLevel())
                    end
                end

                -- Set gryphon art frame level significantly higher than all bars
                pUiMainBarArt:SetFrameLevel(maxLevel + 15)
                
                -- Also ensure individual gryphons have high draw layers
                if MainMenuBarLeftEndCap then
                    MainMenuBarLeftEndCap:SetDrawLayer('OVERLAY', 7)
                end
                if MainMenuBarRightEndCap then
                    MainMenuBarRightEndCap:SetDrawLayer('OVERLAY', 7)
                end
            end
        end
        
        -- Execute immediately to ensure gryphons are on top
        EnsureGryphonsOnTop()

        -- Store module state
        MainbarsModule.frames.pUiMainBar = pUiMainBar
        MainbarsModule.frames.pUiMainBarArt = pUiMainBarArt
        MainbarsModule.actionBarFrames = addon.ActionBarFrames
        MainbarsModule.applied = true
    end

    -- Store functions globally for RefreshMainbarsSystem access
    addon.ApplyActionBarPositions = ApplyActionBarPositions
    addon.PositionActionBarsToContainers = PositionActionBarsToContainers

    -- Initialize immediately since we're already enabled
    ApplyMainbarsSystem()

    -- ========== EVENT HANDLERS FOR XP/REP BARS ==========
    local xpRepEventFrame = CreateFrame("Frame")
    xpRepEventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    xpRepEventFrame:RegisterEvent("UPDATE_EXHAUSTION")
    xpRepEventFrame:RegisterEvent("PLAYER_XP_UPDATE")
    xpRepEventFrame:RegisterEvent("UPDATE_FACTION")
    xpRepEventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    xpRepEventFrame:RegisterEvent("PLAYER_LEVEL_UP")
    xpRepEventFrame:SetScript("OnEvent", function(self, event)
        if not IsModuleEnabled() then return end
        local style = GetXpBarStyle()
        if event == "PLAYER_ENTERING_WORLD" then
            ConnectBarsToEditor()
            if style == "dragonflightui" then
                UpdateDragonflightUIXPBar()
                UpdateDragonflightUIRepBar()
            else
                ApplyRetailUIExpRepBarStyling()
            end
            UpdateBarPositions()
            -- Recalculate dual-bar offset on login/reload
            NotifyDualBarOffsetChanged()
        elseif event == "PLAYER_LEVEL_UP" then
            -- Player leveled up — may have reached max level
            if style == "dragonflightui" then
                UpdateDragonflightUIXPBar()
                UpdateDragonflightUIRepBar()
                -- Re-evaluate exhaustion tick: it self-hides when fully rested
                -- (OnUpdate = nil) and won't re-show without an explicit refresh
                UpdateDfuiExhaustionTick()
            else
                ApplyRetailUIExpRepBarStyling()
            end
            UpdateBarPositions()
            -- Bar visibility changed — recalculate dual-bar offset for all frames
            NotifyDualBarOffsetChanged()
        elseif event == "UPDATE_EXHAUSTION" or event == "PLAYER_XP_UPDATE" then
            if style == "dragonflightui" then
                UpdateDragonflightUIXPBar()
                -- Refresh tick — exhaustion amount changed, tick may need to
                -- show/hide or reposition (e.g. became fully rested or woke up)
                UpdateDfuiExhaustionTick()
            else
                ApplyRetailUIExpRepBarStyling()
            end
            UpdateBarPositions()
        elseif event == "UPDATE_FACTION" then
            if style == "dragonflightui" then
                UpdateDragonflightUIRepBar()
            else
                ApplyRetailUIExpRepBarStyling()
            end
            UpdateBarPositions()
            -- Faction watch changed — rep bar visibility may have changed
            NotifyDualBarOffsetChanged()
        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Combat ended: reposition all bars (secure frames were skipped during combat)
            UpdateBarPositions()
            NotifyDualBarOffsetChanged()
        end
    end)

    -- Single event handler for addon initialization
    local initFrame = CreateFrame("Frame")
    initFrame:RegisterEvent("ADDON_LOADED")
    initFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
    initFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    initFrame:RegisterEvent("PET_BAR_UPDATE")
    initFrame:RegisterEvent("PET_BAR_UPDATE_COOLDOWN")
    initFrame:RegisterEvent("UNIT_PET")
    initFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
    initFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
    initFrame:RegisterEvent("PLAYER_LOGIN")
    initFrame:SetScript("OnEvent", function(self, event, addonName)
        if event == "ADDON_LOADED" and addonName == "DragonUI" then
            if IsModuleEnabled() then
                ApplyMainbarsSystem()
            end

        elseif event == "PLAYER_ENTERING_WORLD" then
            if IsModuleEnabled() then
                -- Remove interfering Blizzard textures
                RemoveBlizzardFrames()

                -- Set up XP/Rep bars for the selected style
                ConnectBarsToEditor()
                local style = GetXpBarStyle()
                if style == "dragonflightui" then
                    UpdateDragonflightUIXPBar()
                    UpdateDragonflightUIRepBar()
                else
                    ApplyRetailUIExpRepBarStyling()
                end
                UpdateBarPositions()

                -- Hide Blizzard text for DFUI (it manages its own).
                -- For RetailUI, ApplyRetailUIExpRepBarStyling manages text visibility.
                if style == "dragonflightui" then
                    if MainMenuBarExpText then MainMenuBarExpText:Hide() end
                    if ReputationWatchBarText then ReputationWatchBarText:Hide() end
                end
                
                -- Ensure gryphons are on top after all setup is complete
                if pUiMainBarArt then
                    local maxLevel = 1
                    local bars = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarLeft, MultiBarRight, pUiMainBar}
                    for _, bar in pairs(bars) do
                        if bar then
                            maxLevel = math.max(maxLevel, bar:GetFrameLevel())
                        end
                    end
                    
                    for _, frame in pairs(addon.ActionBarFrames) do
                        if frame and frame.GetFrameLevel then
                            maxLevel = math.max(maxLevel, frame:GetFrameLevel())
                        end
                    end

                    pUiMainBarArt:SetFrameLevel(maxLevel + 15)
                end
            end

            -- Initialize pet bar visibility - Execute immediately
            if IsModuleEnabled() then
                addon.UpdatePetBarVisibility()
            end

            -- Final reposition and restore bar alpha (hidden during init to prevent flash)
            if not InCombatLockdown() and IsModuleEnabled() then
                ApplyActionBarPositions()
                PositionActionBarsToContainers()
                StabilizeSecondaryBarLayering()
                addon.ApplyAllBarButtonCounts()
            end
            local bars = {MultiBarBottomLeft, MultiBarBottomRight, MultiBarRight, MultiBarLeft}
            for _, bar in ipairs(bars) do
                if bar then bar:SetAlpha(1) end
            end
            if addon.RefreshActionBarVisibility then
                addon.RefreshActionBarVisibility()
            end

            -- Sync Blizzard CVars with DragonUI bar enable/disable settings
            addon.SyncBarCVarsFromProfile()

            self:UnregisterEvent("PLAYER_ENTERING_WORLD")

        elseif event == "PLAYER_LOGIN" then
            -- Set up profile callbacks - Execute immediately
            do
                if addon.db then
                    addon.db.RegisterCallback(addon, "OnProfileChanged", function()
                        -- Execute immediately - no timer needed
                        addon.RefreshMainbarsSystem()
                    end)
                    addon.db.RegisterCallback(addon, "OnProfileCopied", function()
                        -- Execute immediately - no timer needed  
                        addon.RefreshMainbarsSystem()
                    end)
                    addon.db.RegisterCallback(addon, "OnProfileReset", function()
                        -- Execute immediately - no timer needed
                        addon.RefreshMainbarsSystem()
                    end)

                    -- Initial refresh
                    addon.RefreshMainbarsSystem()
                end
            end

            self:UnregisterEvent("PLAYER_LOGIN")

        elseif event == "PLAYER_REGEN_ENABLED" then
            -- Reposition when combat ends - Execute immediately
            if IsModuleEnabled() then
                ApplyActionBarPositions()
                PositionActionBarsToContainers()
                StabilizeSecondaryBarLayering()
                if addon.SetupMainBarPageDriver then
                    addon.SetupMainBarPageDriver(addon.pUiMainBar)
                end
            end

        elseif event == "PET_BAR_UPDATE" or event == "PET_BAR_UPDATE_COOLDOWN" or event == "UNIT_PET" then
            -- Handle pet bar visibility and updates - Execute immediately
            if IsModuleEnabled() and (arg1 == "player" or not arg1) then
                addon.UpdatePetBarVisibility()
            end

        elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
            -- Handle vehicle events that affect pet bar - Execute immediately
            if IsModuleEnabled() and arg1 == "player" then
                addon.UpdatePetBarVisibility()
            end
        end
    end)

    -- Mark module as initialized
    MainbarsModule.initialized = true
    MainbarsModule.applied = true

end

-- ============================================================================
-- BLIZZARD BAR TOGGLE SYNC (bar enable/disable ↔ Interface Options)
-- ============================================================================
-- In WoW 3.3.5a, bar visibility is controlled via global variables
-- SHOW_MULTI_ACTIONBAR_1..4 and persisted by SetActionBarToggles().
-- We sync DragonUI's actionbars.*_enabled settings bidirectionally.

local syncingBars = false

local secondaryBarButtonPrefixes = {
    bottom_left = "MultiBarBottomLeftButton",
    bottom_right = "MultiBarBottomRightButton",
    right = "MultiBarRightButton",
    left = "MultiBarLeftButton",
}

local function IsEditorModeActive()
    return addon.EditorMode and addon.EditorMode.IsActive and addon.EditorMode:IsActive()
end

local function IsSecondaryBarEnabled(config, barName)
    if not config then return false end
    if config[barName .. "_enabled"] == false then
        return false
    end
    -- Blizzard behavior: left bar (Right Bar 2) depends on right bar.
    if barName == "left" and config.right_enabled == false then
        return false
    end
    return true
end

local function SetSecondaryBarButtonsMouseEnabled(barName, enabled)
    if InCombatLockdown() then return end

    local prefix = secondaryBarButtonPrefixes[barName]
    if not prefix then return end

    for i = 1, NUM_ACTIONBAR_BUTTONS do
        local button = _G[prefix .. i]
        if button and button.EnableMouse then
            button:EnableMouse(enabled)
        end
    end
end

local function GetSecondaryBarContainerFrame(barName)
    local frames = addon.ActionBarFrames
    if not frames then return nil end

    local keyMap = {
        bottom_left = "bottombarleft",
        bottom_right = "bottombarright",
        right = "rightbar",
        left = "leftbar",
    }

    local key = keyMap[barName]
    return key and frames[key] or nil
end

local function SetSecondaryBarContainerVisibility(barName, enabled)
    local container = GetSecondaryBarContainerFrame(barName)
    if not container then return end

    if InCombatLockdown() then
        return
    end

    if IsEditorModeActive() then
        if not container:IsShown() then
            container:Show()
        end
        container:SetAlpha(1)
        if container.EnableMouse then
            container:EnableMouse(true)
        end
        return
    end

    if container.EnableMouse then
        container:EnableMouse(false)
    end

    if enabled then
        if not container:IsShown() then
            container:Show()
        end
        container:SetAlpha(1)
    else
        container:SetAlpha(0)
        container:Hide()
    end
end

-- Push DragonUI profile → Blizzard (persistent via SetActionBarToggles)
function addon.SyncBarCVarsFromProfile()
    if syncingBars then return end
    syncingBars = true
    local config = addon.db and addon.db.profile and addon.db.profile.actionbars
    if config then
        local blEnabled = IsSecondaryBarEnabled(config, "bottom_left")
        local brEnabled = IsSecondaryBarEnabled(config, "bottom_right")
        local rEnabled  = IsSecondaryBarEnabled(config, "right")
        local lEnabled  = IsSecondaryBarEnabled(config, "left")

        local bl = blEnabled and 1 or nil
        local br = brEnabled and 1 or nil
        local r  = rEnabled  and 1 or nil
        local l  = lEnabled  and 1 or nil

        -- SetActionBarToggles persists into Blizzard saved variables AND
        -- sets the SHOW_MULTI_ACTIONBAR_* globals AND calls MultiActionBar_Update.
        if SetActionBarToggles then
            SetActionBarToggles(bl, br, r, l)
        end

        -- Keep enabled bars visible immediately, while disabled bars are hidden
        -- and click-through so they cannot block other addons.
        if not InCombatLockdown() then
            local barMap = {
                { name = "bottom_left",  frame = MultiBarBottomLeft,  enabled = blEnabled },
                { name = "bottom_right", frame = MultiBarBottomRight, enabled = brEnabled },
                { name = "right",        frame = MultiBarRight,       enabled = rEnabled },
                { name = "left",         frame = MultiBarLeft,        enabled = lEnabled },
            }
            for _, bar in ipairs(barMap) do
                SetSecondaryBarContainerVisibility(bar.name, bar.enabled)
                SetSecondaryBarButtonsMouseEnabled(bar.name, bar.enabled)
                if bar.frame then
                    if bar.enabled then
                        bar.frame:Show()
                        bar.frame:SetAlpha(1)
                        if bar.frame.EnableMouse then
                            bar.frame:EnableMouse(true)
                        end
                    else
                        if bar.frame.EnableMouse then
                            bar.frame:EnableMouse(false)
                        end
                        bar.frame:SetAlpha(0)
                        bar.frame:Hide()
                    end
                end
            end
        end

        -- Re-apply DragonUI positioning (Blizzard may have moved things)
        if not InCombatLockdown() and addon.ActionBarFrames then
            if addon.PositionActionBarsToContainers then
                addon.PositionActionBarsToContainers()
            end
            addon.ApplyAllBarButtonCounts()
        end
    end
    syncingBars = false

    -- Final visibility pass OUTSIDE the guard so our alpha system is authoritative
    if addon.RefreshActionBarVisibility then
        addon.RefreshActionBarVisibility()
    end
end

-- Pull Blizzard globals → DragonUI profile (called from MultiActionBar_Update hook)
local function SyncBarGlobalsToProfile()
    if syncingBars then return end
    local config = addon.db and addon.db.profile and addon.db.profile.actionbars
    if not config then return end
    config.bottom_left_enabled  = (SHOW_MULTI_ACTIONBAR_1 == 1 or SHOW_MULTI_ACTIONBAR_1 == "1")
    config.bottom_right_enabled = (SHOW_MULTI_ACTIONBAR_2 == 1 or SHOW_MULTI_ACTIONBAR_2 == "1")
    config.right_enabled        = (SHOW_MULTI_ACTIONBAR_3 == 1 or SHOW_MULTI_ACTIONBAR_3 == "1")
    config.left_enabled         = (SHOW_MULTI_ACTIONBAR_4 == 1 or SHOW_MULTI_ACTIONBAR_4 == "1")
    -- Re-apply DragonUI positioning after Blizzard repositioned
    if not InCombatLockdown() and addon.ActionBarFrames then
        if addon.PositionActionBarsToContainers then
            addon.PositionActionBarsToContainers()
        end
        addon.ApplyAllBarButtonCounts()
        if addon.RefreshActionBarVisibility then
            addon.RefreshActionBarVisibility()
        end
    end
end

-- Hook Blizzard's MultiActionBar_Update to capture changes from Interface Options
if MultiActionBar_Update then
    hooksecurefunc("MultiActionBar_Update", SyncBarGlobalsToProfile)
end

-- ============================================================================
-- ACTION BAR VISIBILITY SYSTEM (hover/combat show/hide)
-- ============================================================================
-- Ported from old contributor. Uses alpha-based visibility for the main bar
-- (to keep XP/stance bars visible) and frame-level show/hide for secondary bars.
-- Each bar tracks hovered + inCombat state independently with debounced hover.

-- Visibility state tracking (file scope, survives reloads)
addon.visibilityStates = addon.visibilityStates or {
    main         = { hovered = false, inCombat = false },
    bottom_left  = { hovered = false, inCombat = false },
    bottom_right = { hovered = false, inCombat = false },
    right        = { hovered = false, inCombat = false },
    left         = { hovered = false, inCombat = false },
    micro        = { hovered = false, inCombat = false },
    bag          = { hovered = false, inCombat = false },
}

local VISIBILITY_BAR_ORDER = {
    "main",
    "bottom_left",
    "bottom_right",
    "right",
    "left",
    "micro",
    "bag",
}

local MICROMENU_BUTTON_NAMES = {
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "SocialsMicroButton",
    "LFDMicroButton",
    "CollectionsMicroButton",
    "PVPMicroButton",
    "PathToAscensionMicroButton",
    "ChallengesMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
}

local BAG_BUTTON_NAMES = {
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "KeyRingButton",
}

local function GetVisibilityBarFrameMap()
    local pUiMainBar = addon.pUiMainBar
    return {
        main         = pUiMainBar,
        bottom_left  = MultiBarBottomLeft,
        bottom_right = MultiBarBottomRight,
        right        = MultiBarRight,
        left         = MultiBarLeft,
        micro        = _G.pUiMicroMenu,
        bag          = _G.pUiBagsBar,
    }
end

local function GetVisibilityLogic(config, barName)
    local mode = config and config[barName .. "_visibility_logic"]
    return mode == "or" and "or" or "and"
end

local function EvaluateShouldShowByConditions(config, barName, state)
    local showOnHover = config and config[barName .. "_show_on_hover"]
    local showInCombat = config and config[barName .. "_show_in_combat"]

    if not showOnHover and not showInCombat then
        return true
    end

    if showOnHover and showInCombat then
        local mode = GetVisibilityLogic(config, barName)
        if mode == "or" then
            return state.hovered or state.inCombat
        end
        return state.hovered and state.inCombat
    end

    if showOnHover then
        return state.hovered
    end

    return state.inCombat
end

-- Returns true if a bar has any visibility behavior enabled
local function ShouldUseVisibility(barName)
    local db = addon.db and addon.db.profile and addon.db.profile.actionbars
    if not db then return false end
    return db[barName .. "_show_on_hover"] or db[barName .. "_show_in_combat"]
end

local visibilityAnimations = {}

local function Clamp01(value)
    value = tonumber(value) or 0
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

local function GetVisibilityFadeConfigPrefix(barName)
    if barName == "micro" then
        return "micro_visibility_"
    end
    if barName == "bag" then
        return "bag_visibility_"
    end
    return "visibility_"
end

local function GetVisibilityFadeConfig(barName)
    local db = addon.db and addon.db.profile and addon.db.profile.actionbars
    if not db then
        return 1, 0, 0.15, 0.2
    end

    local prefix = GetVisibilityFadeConfigPrefix(barName)

    local shownAlpha = db[prefix .. "shown_alpha"]
    if shownAlpha == nil then
        shownAlpha = db.visibility_shown_alpha
    end
    shownAlpha = Clamp01(shownAlpha == nil and 1 or shownAlpha)

    local hiddenAlpha = db[prefix .. "hidden_alpha"]
    if hiddenAlpha == nil then
        hiddenAlpha = db.visibility_hidden_alpha
    end
    hiddenAlpha = Clamp01(hiddenAlpha == nil and 0 or hiddenAlpha)

    local fadeInDuration = db[prefix .. "fade_in_duration"]
    if fadeInDuration == nil then
        fadeInDuration = db.visibility_fade_in_duration
    end
    fadeInDuration = math.max(0, tonumber(fadeInDuration) or 0.15)

    local fadeOutDuration = db[prefix .. "fade_out_duration"]
    if fadeOutDuration == nil then
        fadeOutDuration = db.visibility_fade_out_duration
    end
    fadeOutDuration = math.max(0, tonumber(fadeOutDuration) or 0.2)

    return shownAlpha, hiddenAlpha, fadeInDuration, fadeOutDuration
end

local function GetVisibilityFadeOutDelay(barName)
    local db = addon.db and addon.db.profile and addon.db.profile.actionbars
    if not db then return 0.2 end

    local prefix = GetVisibilityFadeConfigPrefix(barName)
    local fadeOutDelay = db[prefix .. "fade_out_delay"]
    if fadeOutDelay == nil then
        fadeOutDelay = db.visibility_fade_out_delay
    end

    return math.max(0, tonumber(fadeOutDelay) or 0.2)
end

local function GetMainBarCurrentAlpha()
    local btn = _G["ActionButton1"]
    if btn and btn.GetAlpha then
        return Clamp01(btn:GetAlpha())
    end
    return 1
end

local SetMainBarArtAlphaDeep

local function ApplyMainBarVisualAlpha(alpha)
    alpha = Clamp01(alpha)

    for i = 1, 12 do
        local btn = _G["ActionButton" .. i]
        if btn then
            btn:SetAlpha(alpha)
            if not InCombatLockdown() then
                btn:Show()
            end
        end
    end

    local buttonsCfg = addon.db and addon.db.profile and addon.db.profile.buttons
    local baseArtAlpha = (buttonsCfg and buttonsCfg.hide_main_bar_background) and 0 or 1
    local artAlpha = alpha * baseArtAlpha
    if addon.pUiMainBarArt then addon.pUiMainBarArt:SetAlpha(artAlpha) end
    if MainMenuBarArtFrame then MainMenuBarArtFrame:SetAlpha(artAlpha) end
    if MainMenuBarLeftEndCap then MainMenuBarLeftEndCap:SetAlpha(alpha) end
    if MainMenuBarRightEndCap then MainMenuBarRightEndCap:SetAlpha(alpha) end
    if ActionBarUpButton then ActionBarUpButton:SetAlpha(artAlpha) end
    if ActionBarDownButton then ActionBarDownButton:SetAlpha(artAlpha) end
    if MainMenuBarPageNumber then MainMenuBarPageNumber:SetAlpha(artAlpha) end
    if addon.pUiMainBar then
        if addon.pUiMainBar.BorderArt then addon.pUiMainBar.BorderArt:SetAlpha(artAlpha) end
        if addon.pUiMainBar.Background then addon.pUiMainBar.Background:SetAlpha(artAlpha) end
    end
    SetMainBarArtAlphaDeep(artAlpha)
end

local function ApplyBarVisibilityAlpha(barName, frame, alpha)
    alpha = Clamp01(alpha)
    if barName == "main" then
        ApplyMainBarVisualAlpha(alpha)
        if frame and not InCombatLockdown() then
            frame:Show()
        end
        return
    end

    if barName == "bag" then
        if MainMenuBarBackpackButton then
            MainMenuBarBackpackButton:SetAlpha(alpha)
        end
    end

    if frame then
        frame:SetAlpha(alpha)
        if ShouldUseVisibility(barName) and not InCombatLockdown() then
            frame:Show()
        end
    end
end

local function FadeBarToAlpha(barName, frame, targetAlpha, duration)
    if not frame then return end

    targetAlpha = Clamp01(targetAlpha)
    duration = math.max(0, tonumber(duration) or 0)

    local currentAlpha = (barName == "main") and GetMainBarCurrentAlpha() or Clamp01(frame:GetAlpha() or 1)

    if math.abs(currentAlpha - targetAlpha) <= 0.01 or duration <= 0 then
        ApplyBarVisibilityAlpha(barName, frame, targetAlpha)
        if visibilityAnimations[barName] and visibilityAnimations[barName].driver then
            visibilityAnimations[barName].driver:SetScript("OnUpdate", nil)
        end
        visibilityAnimations[barName] = nil
        return
    end

    local animation = visibilityAnimations[barName]
    if not animation then
        animation = { driver = CreateFrame("Frame") }
        visibilityAnimations[barName] = animation
    end

    animation.frame = frame
    animation.fromAlpha = currentAlpha
    animation.toAlpha = targetAlpha
    animation.duration = duration
    animation.elapsed = 0

    animation.driver:SetScript("OnUpdate", function(_, elapsed)
        local data = visibilityAnimations[barName]
        if not data then
            return
        end

        data.elapsed = data.elapsed + elapsed
        local progress = data.elapsed / data.duration
        if progress >= 1 then
            ApplyBarVisibilityAlpha(barName, data.frame, data.toAlpha)
            data.driver:SetScript("OnUpdate", nil)
            visibilityAnimations[barName] = nil
            return
        end

        local alpha = data.fromAlpha + ((data.toAlpha - data.fromAlpha) * progress)
        ApplyBarVisibilityAlpha(barName, data.frame, alpha)
    end)
end

-- Deep alpha pass on main bar art textures  (skip functional bars/buttons)
SetMainBarArtAlphaDeep = function(alpha)
    local pUiMainBar    = addon.pUiMainBar
    local pUiMainBarArt = addon.pUiMainBarArt
    if not pUiMainBar then return end

    local function shouldSkip(f)
        if not f then return true end
        if f == MainMenuExpBar or f == ReputationWatchStatusBar
            or f == StanceBarFrame or f == ShapeshiftBarFrame then
            return true
        end
        local n = f.GetName and f:GetName() or ""
        if n and (n:find("ActionButton") or n:find("MultiBar")
            or n:find("BonusActionButton") or n:find("PetActionButton")) then
            return true
        end
        return false
    end

    local function applyToRegions(f)
        if not f or shouldSkip(f) then return end
        for i = 1, (f.GetNumRegions and f:GetNumRegions() or 0) do
            local region = select(i, f:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                region:SetAlpha(alpha)
            end
        end
    end

    for _, container in ipairs({ pUiMainBar, pUiMainBarArt, MainMenuBarArtFrame }) do
        applyToRegions(container)
        if container and container.GetNumChildren then
            for i = 1, container:GetNumChildren() do
                local child = select(i, container:GetChildren())
                applyToRegions(child)
            end
        end
    end
end

-- Core visibility resolver — called every time hover/combat state changes
function addon.UpdateActionBarVisibility(barName, frame)
    if not frame or not addon.db or not addon.db.profile or not addon.db.profile.actionbars then
        return
    end

    -- Skip during vehicle — vehicle module handles bar visibility
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return end

    local config = addon.db.profile.actionbars
    local state  = addon.visibilityStates and addon.visibilityStates[barName]
    if not state then return end

    -- Check if bar is disabled (secondary bars only)
    if barName ~= "main" and barName ~= "micro" and barName ~= "bag" then
        local enabled = IsSecondaryBarEnabled(config, barName)

        SetSecondaryBarContainerVisibility(barName, enabled)
        SetSecondaryBarButtonsMouseEnabled(barName, enabled)

        if not enabled then
            if visibilityAnimations[barName] and visibilityAnimations[barName].driver then
                visibilityAnimations[barName].driver:SetScript("OnUpdate", nil)
                visibilityAnimations[barName] = nil
            end
            if not InCombatLockdown() then
                if frame.EnableMouse then
                    frame:EnableMouse(false)
                end
                frame:Hide()
            end
            frame:SetAlpha(0)
            return
        end
        if not InCombatLockdown() and frame.EnableMouse then
            frame:EnableMouse(true)
        end
    end

    local shownAlpha, hiddenAlpha, fadeInDuration, fadeOutDuration = GetVisibilityFadeConfig(barName)

    -- If neither option enabled, bar is always visible
    if not config[barName .. "_show_on_hover"] and not config[barName .. "_show_in_combat"] then
        if barName == "bag" and addon.RefreshCollapsedSecondaryBagsVisibility then
            addon.RefreshCollapsedSecondaryBagsVisibility(true)
        end
        if barName ~= "main" then
            if not InCombatLockdown() then
                frame:Show()  -- counteract any Blizzard :Hide()
            end
        end
        FadeBarToAlpha(barName, frame, 1, fadeInDuration)
        return
    end

    local shouldShow = EvaluateShouldShowByConditions(config, barName, state)

    if barName == "bag" and addon.RefreshCollapsedSecondaryBagsVisibility then
        addon.RefreshCollapsedSecondaryBagsVisibility(shouldShow)
    end

    if barName ~= "main" and ShouldUseVisibility(barName) and not InCombatLockdown() then
        frame:Show()
    end

    local targetAlpha = shouldShow and shownAlpha or hiddenAlpha
    local duration = shouldShow and fadeInDuration or fadeOutDuration
    FadeBarToAlpha(barName, frame, targetAlpha, duration)
end

-- Refresh all bars (called from options or after profile change)
function addon.RefreshActionBarVisibility()
    if InCombatLockdown() then return end
    -- Skip during vehicle — vehicle module handles bar visibility
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return end

    local barFrames = GetVisibilityBarFrameMap()

    -- Normalise hover state from mouse position
    for barName, frame in pairs(barFrames) do
        local st = addon.visibilityStates[barName]
        if st and frame and frame.IsMouseOver then
            st.hovered = frame:IsMouseOver()
        end
    end

    for barName, frame in pairs(barFrames) do
        if frame then
            addon.UpdateActionBarVisibility(barName, frame)
        end
    end
end

-- Hover detection with 0.25s debounce (uses AceTimer for 3.3.5a compat)
local hoverTimers = {}

local function SetupActionBarHoverDetection(barName, frame)
    if not frame then return end
    if frame.EnableMouse then frame:EnableMouse(true) end

    -- Button prefix for gap-stabilisation hooks
    local buttonPrefix
    if barName == "main"         then buttonPrefix = "ActionButton"
    elseif barName == "bottom_left"  then buttonPrefix = "MultiBarBottomLeftButton"
    elseif barName == "bottom_right" then buttonPrefix = "MultiBarBottomRightButton"
    elseif barName == "right"    then buttonPrefix = "MultiBarRightButton"
    elseif barName == "left"     then buttonPrefix = "MultiBarLeftButton"
    end

    -- Frame enter/leave
    frame:HookScript("OnEnter", function()
        if hoverTimers[barName] and addon.core and addon.core.CancelTimer then
            addon.core:CancelTimer(hoverTimers[barName], true)
            hoverTimers[barName] = nil
        end
        if addon.visibilityStates[barName] then
            addon.visibilityStates[barName].hovered = true
            addon.UpdateActionBarVisibility(barName, frame)
        end
    end)

    frame:HookScript("OnLeave", function()
        if hoverTimers[barName] and addon.core and addon.core.CancelTimer then
            addon.core:CancelTimer(hoverTimers[barName], true)
        end
        if addon.core and addon.core.ScheduleTimer then
            hoverTimers[barName] = addon.core:ScheduleTimer(function()
                if addon.visibilityStates[barName] then
                    addon.visibilityStates[barName].hovered = false
                    addon.UpdateActionBarVisibility(barName, frame)
                end
                hoverTimers[barName] = nil
            end, GetVisibilityFadeOutDelay(barName))
        end
    end)

    -- Button-level hooks stabilise hover across gaps between buttons
    if buttonPrefix then
        for i = 1, 12 do
            local btn = _G[buttonPrefix .. i]
            if btn and not btn.__DragonUI_HoverHooked then
                btn:HookScript("OnEnter", function()
                    if hoverTimers[barName] and addon.core and addon.core.CancelTimer then
                        addon.core:CancelTimer(hoverTimers[barName], true)
                        hoverTimers[barName] = nil
                    end
                    if addon.visibilityStates[barName] then
                        addon.visibilityStates[barName].hovered = true
                        addon.UpdateActionBarVisibility(barName, frame)
                    end
                end)
                btn:HookScript("OnLeave", function()
                    if hoverTimers[barName] and addon.core and addon.core.CancelTimer then
                        addon.core:CancelTimer(hoverTimers[barName], true)
                    end
                    if addon.core and addon.core.ScheduleTimer then
                        hoverTimers[barName] = addon.core:ScheduleTimer(function()
                            if addon.visibilityStates[barName] then
                                addon.visibilityStates[barName].hovered = false
                                addon.UpdateActionBarVisibility(barName, frame)
                            end
                            hoverTimers[barName] = nil
                        end, GetVisibilityFadeOutDelay(barName))
                    end
                end)
                btn.__DragonUI_HoverHooked = true
            end
        end
    end

    local extraButtons = nil
    if barName == "micro" then
        extraButtons = {}
        for _, buttonName in ipairs(MICROMENU_BUTTON_NAMES) do
            local btn = _G[buttonName]
            if btn then
                table.insert(extraButtons, btn)
            end
        end
    elseif barName == "bag" then
        extraButtons = {}
        for _, buttonName in ipairs(BAG_BUTTON_NAMES) do
            local btn = _G[buttonName]
            if btn then
                table.insert(extraButtons, btn)
            end
        end
    end

    if extraButtons then
        for _, btn in ipairs(extraButtons) do
            if btn and not btn.__DragonUI_HoverHooked then
                btn:HookScript("OnEnter", function()
                    if hoverTimers[barName] and addon.core and addon.core.CancelTimer then
                        addon.core:CancelTimer(hoverTimers[barName], true)
                        hoverTimers[barName] = nil
                    end
                    if addon.visibilityStates[barName] then
                        addon.visibilityStates[barName].hovered = true
                        addon.UpdateActionBarVisibility(barName, frame)
                    end
                end)
                btn:HookScript("OnLeave", function()
                    if hoverTimers[barName] and addon.core and addon.core.CancelTimer then
                        addon.core:CancelTimer(hoverTimers[barName], true)
                    end
                    if addon.core and addon.core.ScheduleTimer then
                        hoverTimers[barName] = addon.core:ScheduleTimer(function()
                            if addon.visibilityStates[barName] then
                                addon.visibilityStates[barName].hovered = false
                                addon.UpdateActionBarVisibility(barName, frame)
                            end
                            hoverTimers[barName] = nil
                        end, GetVisibilityFadeOutDelay(barName))
                    end
                end)
                btn.__DragonUI_HoverHooked = true
            end
        end
    end
end

-- Combat state handler
local function OnCombatStateChanged(inCombat)
    local barFrameMap = GetVisibilityBarFrameMap()
    for barName, state in pairs(addon.visibilityStates or {}) do
        state.inCombat = inCombat
        local frame = barFrameMap[barName]
        if frame then
            addon.UpdateActionBarVisibility(barName, frame)
        end
    end
end

-- Initialize the full visibility system (called once after all bars exist)
local function InitializeActionBarVisibility()
    local barFrames = GetVisibilityBarFrameMap()
    if not barFrames.main then return end

    for barName, frame in pairs(barFrames) do
        if frame and not frame.__DragonUI_VisibilityHooked then
            SetupActionBarHoverDetection(barName, frame)
            frame.__DragonUI_VisibilityHooked = true
        end
    end

    if addon.core and addon.core.ScheduleTimer then
        addon.core:ScheduleTimer(function()
            local delayedFrames = GetVisibilityBarFrameMap()
            for barName, frame in pairs(delayedFrames) do
                if frame and not frame.__DragonUI_VisibilityHooked then
                    SetupActionBarHoverDetection(barName, frame)
                    frame.__DragonUI_VisibilityHooked = true
                end
            end
            if addon.RefreshActionBarVisibility then
                addon.RefreshActionBarVisibility()
            end
        end, 2)
    end

    -- Combat events
    local combatFrame = CreateFrame("Frame")
    combatFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
    combatFrame:SetScript("OnEvent", function(self, event)
        OnCombatStateChanged(event == "PLAYER_REGEN_DISABLED")
    end)

    -- Hook Blizzard MultiActionBar_Update to restore our visibility after it re-shows bars
    -- BUT skip during vehicle UI — the vehicle module handles visibility in that case.
    if MultiActionBar_Update then
        hooksecurefunc("MultiActionBar_Update", function()
            -- Never interfere while in a vehicle — vehicle module manages bar hiding
            if UnitHasVehicleUI and UnitHasVehicleUI("player") then return end
            if addon.core and addon.core.ScheduleTimer then
                addon.core:ScheduleTimer(function()
                    if UnitHasVehicleUI and UnitHasVehicleUI("player") then return end
                    if addon.RefreshActionBarVisibility then
                        addon.RefreshActionBarVisibility()
                    end
                end, 0.1)
            end
        end)
    end

    -- Initial visibility pass
    if addon.core and addon.core.ScheduleTimer then
        addon.core:ScheduleTimer(function()
            addon.RefreshActionBarVisibility()
        end, 1)
    end
end

-- ============================================================================
-- INITIALIZATION CONTROL
-- ============================================================================

-- Event frame to handle initialization
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if event == "ADDON_LOADED" and addonName == "DragonUI" then
        -- Only initialize if enabled
        InitializeMainbars()
        self:UnregisterEvent("ADDON_LOADED")
    elseif event == "PLAYER_LOGIN" then
        -- Backup check
        InitializeMainbars()
        -- Initialize visibility system after all bars are created
        InitializeActionBarVisibility()
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)

-- Global UpdateGryphonStyle function (accessible from RefreshMainbarsSystem)
function addon.UpdateGryphonStyle()
    if not MainMenuBarLeftEndCap or not MainMenuBarRightEndCap then
        return
    end

    local db_style = addon.db and addon.db.profile and addon.db.profile.style
    if not db_style then
        db_style = config.style
    end

    local faction = UnitFactionGroup('player')

    if db_style.gryphons == 'old' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -85, -22)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 84, -22)
        MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-left', true)
        MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-right', true)
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    elseif db_style.gryphons == 'new' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -95, -23)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 95, -23)
        if faction == 'Alliance' then
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-thick-right', true)
        else
            MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-left', true)
            MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-wyvern-thick-right', true)
        end
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    elseif db_style.gryphons == 'flying' then
        MainMenuBarLeftEndCap:SetClearPoint('BOTTOMLEFT', -80, -21)
        MainMenuBarRightEndCap:SetClearPoint('BOTTOMRIGHT', 80, -21)
        MainMenuBarLeftEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-left', true)
        MainMenuBarRightEndCap:set_atlas('ui-hud-actionbar-gryphon-flying-right', true)
        MainMenuBarLeftEndCap:Show()
        MainMenuBarRightEndCap:Show()
    else
        MainMenuBarLeftEndCap:Hide()
        MainMenuBarRightEndCap:Hide()
    end
end

-- ============================================================================
-- BAR SIZE SYSTEM - Grid-based button layout
-- ============================================================================

-- Apply all bar button counts from database
function addon.ApplyAllBarButtonCounts()
    if InCombatLockdown() then return end

    local db = addon.db and addon.db.profile and addon.db.profile.mainbars
    if not db then return end

    local btnSpacing = db.button_spacing or ACTION_BUTTON_SPACING

    -- Main bar: use grid layout from player sub-table
    local playerCfg = db.player or {}
    local mainColumns = playerCfg.columns or 12
    local mainCount = playerCfg.buttons_shown or 12
    -- Auto-compute rows from columns and buttons shown
    local mainRows = math.ceil(mainCount / mainColumns)

    -- Main bar uses ArrangeActionBarButtons for grid layout
    addon.ArrangeActionBarButtons("ActionButton",
        addon.pUiMainBar, addon.pUiMainBar,
        mainRows, mainColumns, mainCount,
        nil, nil, btnSpacing)

    -- Also apply same layout to BonusActionButtons (vehicle/shapeshift override bar)
    addon.ArrangeActionBarButtons("BonusActionButton",
        nil, addon.pUiMainBar,
        mainRows, mainColumns, mainCount,
        nil, nil, btnSpacing)
    EnsureBonusButtonsClickThrough()

    -- Show/hide ThreeSlice dividers between buttons
    -- Only show dividers in single-row mode (multi-row would look odd)
    if addon.MainBarDividers then
        for i = 1, 11 do
            local div = addon.MainBarDividers[i]
            if div then
                if mainRows == 1 and i < mainCount then
                    -- Single row: show divider between two visible buttons
                    if div.top then div.top:Show() end
                    if div.mid then div.mid:Show() end
                    if div.bottom then div.bottom:Show() end
                else
                    -- Multi-row or beyond last button: hide
                    if div.top then div.top:Hide() end
                    if div.mid then div.mid:Hide() end
                    if div.bottom then div.bottom:Hide() end
                end
            end
        end
    end

    -- Reposition gryphons to hug the resized main bar
    addon.UpdateGryphonStyle()

    -- NOTE: Container frames (editor overlays) are NOT resized here.
    -- Resizing containers shifts bars depending on their anchor point.
    -- Only pUiMainBar (with NineSlice/gryphons) resizes via ArrangeActionBarButtons above.
    -- Containers keep their initial size set by CreateActionBarFrames / PositionActionBars.

    -- Bottom Left bar — use grid layout (no padding)
    -- Pass bar as parentFrame so it gets resized to match buttons.
    -- This ensures CENTER anchoring keeps buttons visually centered.
    local blCfg = db.bottom_left or {}
    local blCols = blCfg.columns or 12
    local blCount = blCfg.buttons_shown or 12
    local blRows = math.ceil(blCount / blCols)
    if not MultiBarBottomLeft or MultiBarBottomLeft:IsShown() then
        addon.ArrangeActionBarButtons("MultiBarBottomLeftButton",
            MultiBarBottomLeft, MultiBarBottomLeft,
            blRows, blCols, blCount,
            0, 0, btnSpacing)
    end

    -- Bottom Right bar — use grid layout (no padding)
    local brCfg = db.bottom_right or {}
    local brCols = brCfg.columns or 12
    local brCount = brCfg.buttons_shown or 12
    local brRows = math.ceil(brCount / brCols)
    if not MultiBarBottomRight or MultiBarBottomRight:IsShown() then
        addon.ArrangeActionBarButtons("MultiBarBottomRightButton",
            MultiBarBottomRight, MultiBarBottomRight,
            brRows, brCols, brCount,
            0, 0, btnSpacing)
    end

    -- Left/Right bars: uses TOPLEFT grid layout via PositionSideBarButtons
    -- which respects columns setting (1=vertical, 12=horizontal, etc.)
    if addon.PositionActionBars then
        addon.PositionActionBars()
    elseif addon.PositionActionBarsToContainers then
        addon.PositionActionBarsToContainers()
    end

    -- Keep overlay sizes in sync with current layout
    if addon.UpdateOverlaySizes then
        addon.UpdateOverlaySizes()
    end
end

-- Public API for options
function addon.RefreshMainbarsSystem()
    if not IsModuleEnabled() then
        addon:ShouldDeferModuleDisable("mainbars", MainbarsModule)
        return
    end

    -- CRITICAL: Don't touch protected frames during combat
    if InCombatLockdown() then
        -- Only update safe things (not frames)
        addon.UpdateGryphonStyle()
        if addon.MainMenuBarMixin and addon.MainMenuBarMixin.update_main_bar_background then
            addon.MainMenuBarMixin:update_main_bar_background()
        end
        return
    end

    -- Apply scales to all action bars (ONLY OUTSIDE COMBAT)
    local db = addon.db and addon.db.profile and addon.db.profile.mainbars
    if not db then
        return
    end

    -- Apply main bar scale
    if addon.pUiMainBar and db.scale_actionbar then
        addon.pUiMainBar:SetScale(db.scale_actionbar)
    end

    -- Apply scales to other bars
    if MultiBarRight and db.scale_rightbar then
        MultiBarRight:SetScale(db.scale_rightbar)
    end

    if MultiBarLeft and db.scale_leftbar then
        MultiBarLeft:SetScale(db.scale_leftbar)
    end

    if MultiBarBottomLeft and db.scale_bottomleft then
        MultiBarBottomLeft:SetScale(db.scale_bottomleft)
    end

    if MultiBarBottomRight and db.scale_bottomright then
        MultiBarBottomRight:SetScale(db.scale_bottomright)
    end

    -- Update gryphon style and background
    addon.UpdateGryphonStyle()
    if addon.MainMenuBarMixin and addon.MainMenuBarMixin.update_main_bar_background then
        addon.MainMenuBarMixin:update_main_bar_background()
    end

    -- Update widget positions if available
    if addon.ActionBarFrames and addon.ApplyActionBarPositions then
        addon.ApplyActionBarPositions()
        if addon.PositionActionBarsToContainers then
            addon.PositionActionBarsToContainers()
        end
    end

    -- Apply bar button counts (show/hide buttons)
    -- This also calls PositionActionBars() at the end for left/right bar orientation
    addon.ApplyAllBarButtonCounts()

    -- Refresh XP/Rep bars (style, sizing, positioning)
    if addon.RefreshXpRepBars then
        addon.RefreshXpRepBars()
    end
end

-- Alias for compatibility
addon.RefreshMainbars = addon.RefreshMainbarsSystem
