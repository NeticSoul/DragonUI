--[[
================================================================================
DragonUI - API Functions
================================================================================
This file contains utility functions used throughout DragonUI.
These are general-purpose functions that can be used by any module.
================================================================================
]]

local addon = select(2, ...)
local L = addon.L

addon.DB_SCHEMA_VERSION = 2
addon.RELEASE_VERSION = GetAddOnMetadata("DragonUI", "Version") or "2.5"

-- ============================================================================
-- TABLE UTILITIES
-- ============================================================================

-- Recursively copy tables
function addon.DeepCopy(source, target)
    target = target or {}
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            addon.DeepCopy(value, target[key])
        else
            target[key] = value
        end
    end
    return target
end

-- Count elements in a table (works with non-sequential tables)
function addon:tcount(tbl)
    local count = 0
    for _ in pairs(tbl) do count = count + 1 end
    return count
end

-- "^" only anchors as the first char of the whole pattern; inside a capture it matches a literal caret.
local function UpperCamelCase(name)
    return (name:gsub("^%l", string.upper):gsub("_(%l)", string.upper))
end

local function ApplyMissingDefaults(source, target)
    if type(source) ~= "table" or type(target) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end
            ApplyMissingDefaults(value, target[key])
        elseif target[key] == nil then
            target[key] = value
        end
    end
end

-- Register unit-filtered events when supported by the client; otherwise fall
-- back to RegisterEvent for compatibility across 3.3.5a variants.
function addon.RegisterUnitEventSafe(frame, eventName, ...)
    if not frame or not eventName then
        return false
    end

    local hasUnitToken = false
    for i = 1, select("#", ...) do
        if select(i, ...) ~= nil then
            hasUnitToken = true
            break
        end
    end

    if type(frame.RegisterUnitEvent) == "function" and hasUnitToken then
        return frame:RegisterUnitEvent(eventName, ...)
    end

    frame:RegisterEvent(eventName)
    return true
end

-- ============================================================================
-- FRAME CREATION AND MANAGEMENT
-- ============================================================================

-- Frames registry for editor mode
addon.frames = addon.frames or {}

-- Editor mode texture base path
local EDITMODE_TEXTURE_BASE = 'Interface\\AddOns\\DragonUI\\Textures\\Editmode\\'

-- Nineslice texture coordinates
local NINESLICE_COORDS = {
    highlight = {
        corner = {0.03125, 0.53125, 0.285156, 0.347656},
        topEdge = {0, 0.5, 0.0742188, 0.136719},
        bottomEdge = {0, 0.5, 0.00390625, 0.0664062},
        leftEdge = {0.0078125, 0.132812, 0, 1},
        rightEdge = {0.148438, 0.273438, 0, 1}
    },
    selected = {
        corner = {0.03125, 0.53125, 0.355469, 0.417969},
        topEdge = {0, 0.5, 0.214844, 0.277344},
        bottomEdge = {0, 0.5, 0.144531, 0.207031},
        leftEdge = {0.289062, 0.414062, 0, 1},
        rightEdge = {0.429688, 0.554688, 0, 1}
    }
}

-- Add nineslice border to a frame
local function AddNineslice(frame)
    frame.NineSlice = {}
    local slice = frame.NineSlice
    
    -- Top left corner (no rotation needed)
    slice.TopLeftCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.TopLeftCorner:SetSize(16, 16)
    slice.TopLeftCorner:SetPoint('TOPLEFT', -8, 8)
    
    -- Top right corner (will be rotated via SetTexCoord)
    slice.TopRightCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.TopRightCorner:SetSize(16, 16)
    slice.TopRightCorner:SetPoint('TOPRIGHT', 8, 8)
    
    -- Bottom left corner (will be rotated via SetTexCoord)
    slice.BottomLeftCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.BottomLeftCorner:SetSize(16, 16)
    slice.BottomLeftCorner:SetPoint('BOTTOMLEFT', -8, -8)
    
    -- Bottom right corner (will be rotated via SetTexCoord)
    slice.BottomRightCorner = frame:CreateTexture(nil, 'OVERLAY')
    slice.BottomRightCorner:SetSize(16, 16)
    slice.BottomRightCorner:SetPoint('BOTTOMRIGHT', 8, -8)
    
    -- Top edge (connects corners)
    slice.TopEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.TopEdge:SetPoint('TOPLEFT', slice.TopLeftCorner, 'TOPRIGHT')
    slice.TopEdge:SetPoint('BOTTOMRIGHT', slice.TopRightCorner, 'BOTTOMLEFT')
    
    -- Bottom edge
    slice.BottomEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.BottomEdge:SetPoint('TOPLEFT', slice.BottomLeftCorner, 'TOPRIGHT')
    slice.BottomEdge:SetPoint('BOTTOMRIGHT', slice.BottomRightCorner, 'BOTTOMLEFT')
    
    -- Left edge
    slice.LeftEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.LeftEdge:SetPoint('TOPLEFT', slice.TopLeftCorner, 'BOTTOMLEFT')
    slice.LeftEdge:SetPoint('BOTTOMRIGHT', slice.BottomLeftCorner, 'TOPRIGHT')
    
    -- Right edge
    slice.RightEdge = frame:CreateTexture(nil, 'OVERLAY')
    slice.RightEdge:SetPoint('TOPLEFT', slice.TopRightCorner, 'BOTTOMLEFT')
    slice.RightEdge:SetPoint('BOTTOMRIGHT', slice.BottomRightCorner, 'TOPRIGHT')
    
    -- Center (background)
    slice.Center = frame:CreateTexture(nil, 'BACKGROUND')
    slice.Center:SetPoint('TOPLEFT', 0, 0)
    slice.Center:SetPoint('BOTTOMRIGHT', 0, 0)
end

-- Helper function to apply rotated tex coords using 8-value SetTexCoord
-- SetTexCoord(ULx, ULy, LLx, LLy, URx, URy, LRx, LRy)
local function SetTexCoordRotated(texture, coords, rotation)
    local l, r, t, b = coords[1], coords[2], coords[3], coords[4]
    
    if rotation == 0 then
        -- Normal (0°): TopLeft corner
        texture:SetTexCoord(l, t, l, b, r, t, r, b)
    elseif rotation == 90 then
        -- 90° CW: BottomLeft corner
        texture:SetTexCoord(l, b, r, b, l, t, r, t)
    elseif rotation == 180 then
        -- 180°: BottomRight corner
        texture:SetTexCoord(r, b, r, t, l, b, l, t)
    elseif rotation == 270 then
        -- 270° CW (-90°): TopRight corner
        texture:SetTexCoord(r, t, l, t, r, b, l, b)
    end
end

-- Apply highlight or selected state to nineslice
local function SetNinesliceState(frame, selected)
    local slice = frame.NineSlice
    if not slice then return end
    
    local coords = selected and NINESLICE_COORDS.selected or NINESLICE_COORDS.highlight
    
    -- Corners use same texture with different coords and rotations
    local cornerTexture = EDITMODE_TEXTURE_BASE .. 'EditModeUI'
    
    -- TopLeft (0° - normal)
    slice.TopLeftCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.TopLeftCorner, coords.corner, 0)
    
    -- TopRight (90° CW)
    slice.TopRightCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.TopRightCorner, coords.corner, 90)
    
    -- BottomLeft (270° CW / -90°)
    slice.BottomLeftCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.BottomLeftCorner, coords.corner, 270)
    
    -- BottomRight (180°)
    slice.BottomRightCorner:SetTexture(cornerTexture)
    SetTexCoordRotated(slice.BottomRightCorner, coords.corner, 180)
    
    -- Edges
    slice.TopEdge:SetTexture(cornerTexture)
    slice.TopEdge:SetTexCoord(unpack(coords.topEdge))
    slice.BottomEdge:SetTexture(cornerTexture)
    slice.BottomEdge:SetTexCoord(unpack(coords.bottomEdge))
    
    local verticalTexture = EDITMODE_TEXTURE_BASE .. 'EditModeUIVertical'
    slice.LeftEdge:SetTexture(verticalTexture)
    slice.LeftEdge:SetTexCoord(unpack(coords.leftEdge))
    slice.RightEdge:SetTexture(verticalTexture)
    slice.RightEdge:SetTexCoord(unpack(coords.rightEdge))
    
    -- Center background
    local centerTexture = selected and 'EditModeUISelectedBackground' or 'EditModeUIHighlightBackground'
    slice.Center:SetTexture(EDITMODE_TEXTURE_BASE .. centerTexture)
    slice.Center:SetTexCoord(0, 1, 0, 1)
end

-- Show nineslice overlay
local function ShowNineslice(frame)
    local slice = frame.NineSlice
    if not slice then return end
    
    for _, part in pairs(slice) do
        part:Show()
    end
end

-- Hide nineslice overlay
local function HideNineslice(frame)
    local slice = frame.NineSlice
    if not slice then return end
    
    for _, part in pairs(slice) do
        part:Hide()
    end
end

-- Create a UI frame with editor mode support
function addon.CreateUIFrame(width, height, frameName)
    local frame = CreateFrame("Frame", 'DragonUI_' .. frameName, UIParent)
    frame:SetSize(width, height)

    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(false)
    frame:SetMovable(false)
    
    frame:SetScript("OnDragStart", function(self, button)
        self:StartMoving()
        -- Ensure this frame is the selected one
        if addon.selectedEditorFrame ~= self then
            addon.SelectEditorFrame(self)
        end
        -- While dragging: remove green tint, show default drag nineslice
        addon.ClearSelectionTint(self)
    end)
    
    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        
        -- AUTO-SAVE: Find this frame in EditableFrames and save position automatically
        for name, frameData in pairs(addon.EditableFrames) do
            if frameData.frame == self then
                -- Save position automatically
                if frameData.configPath and #frameData.configPath == 2 then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1], frameData.configPath[2])
                elseif frameData.configPath then
                    addon.SaveUIFramePosition(frameData.frame, frameData.configPath[1])
                end
                break
            end
        end
        -- Re-apply green tint now that drag is done (frame stays selected)
        addon.ApplySelectionTint(self)
    end)
    
    -- Click without drag also selects the frame
    frame:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            addon.SelectEditorFrame(self)
        end
    end)

    frame:SetFrameLevel(100)
    frame:SetFrameStrata('FULLSCREEN')

    -- Create nineslice overlay (DragonflightUI style)
    AddNineslice(frame)
    SetNinesliceState(frame, false) -- Default to highlight state
    HideNineslice(frame) -- Start hidden
    
    -- Legacy editorTexture reference (for backwards compatibility)
    frame.editorTexture = frame.NineSlice.Center

    -- Text label for editor mode (auto-translate via locale)
    do
        local L = addon.L
        local fontString = frame:CreateFontString(nil, "OVERLAY", 'GameFontNormal')
        fontString:SetPoint("CENTER", frame, "CENTER", 0, 0)
        local ok, translated = pcall(function() return L and L[frameName] end)
        fontString:SetText((ok and translated) or frameName)
        fontString:Hide()
        frame.editorText = fontString
    end

    return frame
end

-- Export nineslice functions for modules with custom behavior
addon.AddNineslice = AddNineslice
addon.SetNinesliceState = SetNinesliceState
addon.ShowNineslice = ShowNineslice
addon.HideNineslice = HideNineslice

-- ============================================================================
-- FRAME VISIBILITY FUNCTIONS (Editor Mode Support)
-- ============================================================================

-- Show a UI frame (disable editor mode for this frame)
function addon.ShowUIFrame(frame)
    frame:SetMovable(false)
    frame:EnableMouse(false)
    
    -- Hide nineslice overlay (new system)
    if frame.NineSlice then
        HideNineslice(frame)
    elseif frame.editorTexture then
        -- Legacy fallback for frames not using CreateUIFrame
        frame.editorTexture:Hide()
    end
    
    if frame.editorText then
        frame.editorText:Hide()
    end

    if addon.frames[frame] then
        for _, target in pairs(addon.frames[frame]) do
            target:SetAlpha(1)
        end
        addon.frames[frame] = nil
    end
end

-- Hide a UI frame (enable editor mode for this frame)
function addon.HideUIFrame(frame, exclude)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    
    -- Show nineslice overlay (new system)
    if frame.NineSlice then
        SetNinesliceState(frame, false) -- Highlight state
        ShowNineslice(frame)
    elseif frame.editorTexture then
        -- Legacy fallback for frames not using CreateUIFrame
        frame.editorTexture:Show()
    end
    
    if frame.editorText then
        frame.editorText:Show()
    end

    addon.frames[frame] = {}
    exclude = exclude or {}

    for _, target in pairs(exclude) do
        target:SetAlpha(0)
        table.insert(addon.frames[frame], target)
    end
end

-- ============================================================================
-- POSITION SAVE/LOAD FUNCTIONS
-- ============================================================================

-- Save frame position to database
function addon.SaveUIFramePosition(frame, configPath1, configPath2)
    if not frame then
        return
    end

    local anchor, _, _, posX, posY = frame:GetPoint(1)

    -- Strip dual-bar offset from positions of affected widgets so the
    -- database always stores the *base* position.  Without this, closing
    -- editor mode while both XP+Rep bars are visible would bake the
    -- offset into the saved Y, breaking IsWidgetAtDefaultPosition.
    -- IMPORTANT: Only strip when the widget is still at its default spot
    -- (i.e.the offset was actually added).  For user-moved frames the
    -- offset was never applied, so subtracting it would cause drift.
    if configPath1 == "widgets" and configPath2
       and addon._dualBarOffsetWidgets and addon._dualBarOffsetWidgets[configPath2]
       and addon.GetDualBarVerticalOffset and addon.IsWidgetAtDefaultPosition
       and addon.IsWidgetAtDefaultPosition(configPath2) then
        local offset = addon.GetDualBarVerticalOffset()
        if offset > 0 and posY then
            posY = posY - offset
        end
    end

    -- Handle nested paths (widgets.player)
    if configPath2 then
        -- Case: SaveUIFramePosition(frame, "widgets", "player")
        if not addon.db.profile[configPath1] then
            addon.db.profile[configPath1] = {}
        end

        if not addon.db.profile[configPath1][configPath2] then
            addon.db.profile[configPath1][configPath2] = {}
        end

        addon.db.profile[configPath1][configPath2].anchor = anchor or "CENTER"
        addon.db.profile[configPath1][configPath2].posX = posX or 0
        addon.db.profile[configPath1][configPath2].posY = posY or 0
    else
        -- Case: SaveUIFramePosition(frame, "minimap") - backwards compatibility
        local widgetName = configPath1
        
        if not addon.db.profile.widgets then
            addon.db.profile.widgets = {}
        end

        if not addon.db.profile.widgets[widgetName] then
            addon.db.profile.widgets[widgetName] = {}
        end

        addon.db.profile.widgets[widgetName].anchor = anchor or "CENTER"
        addon.db.profile.widgets[widgetName].posX = posX or 0
        addon.db.profile.widgets[widgetName].posY = posY or 0
    end
end

-- Apply a saved widgets.* position to a frame (position presets / reload helpers)
function addon.ApplyWidgetPositionFromDB(widgetKey, frame)
    if not widgetKey or not frame or not addon.db or not addon.db.profile or not addon.db.profile.widgets then
        return
    end

    local cfg = addon.db.profile.widgets[widgetKey]
    if not cfg or (cfg.posX == nil and cfg.posY == nil) then
        return
    end

    local anchor = cfg.anchor or "CENTER"
    local posX = cfg.posX or 0
    local posY = cfg.posY or 0

    if addon._dualBarOffsetWidgets and addon._dualBarOffsetWidgets[widgetKey]
       and addon.GetDualBarVerticalOffset and addon.IsWidgetAtDefaultPosition
       and addon.IsWidgetAtDefaultPosition(widgetKey) then
        posY = posY + addon.GetDualBarVerticalOffset()
    end

    if InCombatLockdown() then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(anchor, UIParent, anchor, posX, posY)
end

-- Apply frame position from database
function addon.ApplyUIFramePosition(frame, configPath)
    if not frame or not configPath then
        return
    end

    local section, key = configPath:match("([^%.]+)%.([^%.]+)")
    if not section or not key then
        return
    end

    local config = addon.db.profile[section] and addon.db.profile[section][key]
    if not config or not config.override then
        return
    end

    frame:ClearAllPoints()
    frame:SetPoint(config.anchor or "CENTER", UIParent, config.anchorParent or "CENTER", config.x or 0, config.y or 0)
end

-- ============================================================================
-- SETTINGS VALIDATION
-- ============================================================================

-- Check if settings exist and load defaults if needed
function addon.CheckSettingsExists(moduleTable, configPaths)
    local needsDefaults = false

    for _, configPath in pairs(configPaths) do
        local section, key = configPath:match("([^%.]+)%.([^%.]+)")
        if section and key then
            if not addon.db.profile[section] or not addon.db.profile[section][key] then
                needsDefaults = true
                break
            end
        end
    end

    if needsDefaults and moduleTable.LoadDefaultSettings then
        moduleTable:LoadDefaultSettings()
    end

    if moduleTable.UpdateWidgets then
        moduleTable:UpdateWidgets()
    end
end

-- ============================================================================
-- EDITABLE FRAMES REGISTRY
-- Centralized system for managing moveable UI elements
-- ============================================================================

addon.EditableFrames = addon.EditableFrames or {}

-- Register a frame as editable
function addon:RegisterEditableFrame(frameInfo)
    local frameData = {
        name = frameInfo.name,                    -- "player", "minimap", "target"
        frame = frameInfo.frame,                  -- The auxiliary frame
        blizzardFrame = frameInfo.blizzardFrame,  -- Real Blizzard frame (optional)
        configPath = frameInfo.configPath,        -- {"widgets", "player"} or {"unitframe", "target"}
        onShow = frameInfo.onShow,                -- Optional function when showing editor
        onHide = frameInfo.onHide,                -- Optional function when hiding editor
        onNudge = frameInfo.onNudge,               -- Optional function after arrow-key/typed coordinate edits
        showTest = frameInfo.showTest,            -- Function to show with fake data
        hideTest = frameInfo.hideTest,            -- Function to hide fake frame
        hasTarget = frameInfo.hasTarget,          -- Function to check if should be visible
        editorVisible = frameInfo.editorVisible,  -- Function to check if frame should appear in editor mode
        module = frameInfo.module                 -- Reference to the module
    }
    
    self.EditableFrames[frameInfo.name] = frameData
end

-- ============================================================================
-- MODULE REGISTRY SYSTEM
-- ============================================================================
-- Central registry for all DragonUI modules.
-- Provides: auto-discovery, status reporting, batch enable/disable operations.
-- Modules self-register during load, making the system extensible.

addon.ModuleRegistry = addon.ModuleRegistry or {
    -- Registered modules: { [name] = { module, displayName, description, order } }
    modules = {},
    -- Load order for enable/disable operations
    loadOrder = {},
    -- Counter for auto-ordering
    orderCounter = 0,
    legacyRefreshTargets = {},
}

local MR = addon.ModuleRegistry

local MODULE_LIFECYCLE_OVERRIDES = {
    boss = {
        refresh = "RefreshBossFrames",
        loadOnce = true,
        isEnabled = function()
            return addon.UF and addon.UF.IsEnabled and addon.UF.IsEnabled("boss")
        end,
    },
    buffs = {
        refresh = "RefreshBuffFrame",
        loadOnce = true,
        isEnabled = function()
            return addon.db and addon.db.profile and addon.db.profile.buffs and addon.db.profile.buffs.enabled
        end,
    },
    buttons = { refresh = "RefreshButtons", loadOnce = true },
    chatmods = {
        apply = "ApplyChatModsSystem",
        restore = "RestoreChatModsSystem",
        loadOnce = true,
    },
    bagster = {
        apply = "ApplyBagsterSystem",
        restore = "RestoreBagsterSystem",
        loadOnce = true,
    },
    cooldowns = { refresh = "RefreshCooldowns", loadOnce = true },
    darkmode = { apply = "ApplyDarkMode", restore = "RestoreDarkMode", loadOnce = true },
    itemquality = {
        apply = "ApplyItemQualitySystem",
        restore = "RestoreItemQualitySystem",
        loadOnce = true,
    },
    mainbars = { refresh = "RefreshMainbarsSystem", loadOnce = true },
    micromenu = { refresh = "RefreshMicromenuSystem", loadOnce = true },
    minimap = { refresh = "RefreshMinimapSystem", loadOnce = true },
    nameplates = {
        apply = "ApplyNameplatesSystem",
        restore = "RestoreNameplatesSystem",
        refresh = "RefreshNameplates",
        loadOnce = true,
    },
    multicast = { refresh = "RefreshMulticast", loadOnce = true },
    noop = { refresh = "RefreshNoopSystem", loadOnce = true },
    petbar = { refresh = "RefreshPetbarSystem", loadOnce = true },
    player = {
        refresh = function()
            if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                addon.PlayerFrame.RefreshPlayerFrame()
            end
        end,
        loadOnce = true,
        isEnabled = function()
            return addon.UF and addon.UF.IsEnabled and addon.UF.IsEnabled("player")
        end,
    },
    questtracker = { refresh = "RefreshQuestTracker", loadOnce = true },
    stance = { refresh = "RefreshStanceSystem", loadOnce = true },
    tooltip = {
        apply = "ApplyTooltipSystem",
        restore = "RestoreTooltipSystem",
        loadOnce = true,
    },
    unitframe_layers = { refresh = "RefreshUnitFrameLayers", loadOnce = true },
    vehicle = { refresh = "RefreshVehicleSystem", loadOnce = true },
}

local DEFAULT_LEGACY_REFRESH_TARGETS = {
    { name = "targetframe", funcName = "RefreshTargetFrame", order = 900 },
    { name = "focusframe", funcName = "RefreshFocusFrame", order = 910 },
    { name = "partyframes", funcName = "RefreshPartyFrames", order = 920 },
}

local function ResolveRegistryFunction(info, phase)
    local mod = info and info.module
    local override = info and info.lifecycle or nil
    local prefix = info and info.lifecyclePrefix or nil
    local candidates = {}

    if override and override[phase] then
        table.insert(candidates, override[phase])
    end

    if phase == "refresh" then
        table.insert(candidates, "Refresh" .. prefix .. "System")
        table.insert(candidates, "Refresh" .. prefix)
        table.insert(candidates, "Refresh")
        table.insert(candidates, "OnProfileChanged")
        table.insert(candidates, "Enable")
    elseif phase == "apply" then
        table.insert(candidates, "Apply" .. prefix .. "System")
        table.insert(candidates, "Apply" .. prefix)
        table.insert(candidates, "Apply")
        table.insert(candidates, "Enable")
        table.insert(candidates, "OnEnable")
    elseif phase == "restore" then
        table.insert(candidates, "Restore" .. prefix .. "System")
        table.insert(candidates, "Restore" .. prefix)
        table.insert(candidates, "Restore")
        table.insert(candidates, "Disable")
        table.insert(candidates, "OnDisable")
    end

    for _, candidate in ipairs(candidates) do
        if type(candidate) == "function" then
            return candidate, false
        end
        if type(candidate) == "string" then
            if mod and type(mod[candidate]) == "function" then
                return mod[candidate], true
            end
            if type(addon[candidate]) == "function" then
                return addon[candidate], false
            end
        end
    end

    return nil, false
end

-- Register a module with the registry
-- @param name: Unique module identifier (matches database key in profile.modules)
-- @param moduleTable: The module state table (e.g., StanceModule)
-- @param displayName: Human-readable name for UI display
-- @param description: Description for tooltips (optional)
-- @param order: Load order number (optional, auto-assigned if nil)
function MR:Register(name, moduleTable, displayName, description, orderOrOptions)
    local L = addon.L

    if not name or not moduleTable then
        addon:Error(L["ModuleRegistry:Register requires name and moduleTable"])
        return false
    end
    
    -- Prevent duplicate registration
    if self.modules[name] then
        addon:Debug(L["ModuleRegistry: Module already registered -"], name)
        return false
    end
    
    -- Auto-assign order if not provided
    local options = nil
    if type(orderOrOptions) == "table" then
        options = orderOrOptions
    elseif type(orderOrOptions) == "number" then
        options = { order = orderOrOptions }
    else
        options = {}
    end

    self.orderCounter = self.orderCounter + 1
    local assignedOrder = options.order or self.orderCounter
    local lifecycle = options.lifecycle or MODULE_LIFECYCLE_OVERRIDES[name] or {}
    
    -- Store module info
    self.modules[name] = {
        module = moduleTable,
        displayName = displayName or name,
        description = description or "",
        order = assignedOrder,
        lifecyclePrefix = options.lifecyclePrefix or lifecycle.lifecyclePrefix or UpperCamelCase(name),
        lifecycle = lifecycle,
        loadOnce = options.loadOnce or lifecycle.loadOnce or false,
        isEnabled = options.isEnabled or lifecycle.isEnabled,
    }
    
    -- Add to load order
    table.insert(self.loadOrder, name)
    
    addon:Debug(L["ModuleRegistry: Registered module -"], name, L["order:"], assignedOrder)
    return true
end

function MR:RegisterLegacyRefreshTarget(name, funcName, order)
    if not name or not funcName then
        return false
    end

    self.legacyRefreshTargets[name] = {
        funcName = funcName,
        order = order or 1000,
    }

    return true
end

function MR:EnsureLegacyRefreshTargets()
    if next(self.legacyRefreshTargets) then
        return
    end

    for _, target in ipairs(DEFAULT_LEGACY_REFRESH_TARGETS) do
        self:RegisterLegacyRefreshTarget(target.name, target.funcName, target.order)
    end
end

-- Get a registered module by name
-- @param name: Module identifier
-- @return moduleTable or nil
function MR:Get(name)
    local info = self.modules[name]
    return info and info.module or nil
end

-- Get module info (name, description, order)
-- @param name: Module identifier
-- @return table { module, displayName, description, order } or nil
function MR:GetInfo(name)
    return self.modules[name]
end

-- Get all registered module names
-- @return table (array) of module names in load order
function MR:GetAll()
    return self.loadOrder
end

-- Get count of registered modules
-- @return number
function MR:Count()
    return #self.loadOrder
end

-- Check if a module is enabled in database
-- @param name: Module identifier
-- @return boolean
function MR:IsEnabled(name)
    local info = self.modules[name]
    if info and info.isEnabled then
        return info.isEnabled()
    end

    if not addon.db or not addon.db.profile or not addon.db.profile.modules then
        return false
    end

    local cfg = addon.db.profile.modules[name]
    return cfg and cfg.enabled
end

function MR:IsLoadOnce(name)
    local info = self.modules[name]
    return info and info.loadOnce or false
end

function addon:IsModuleLoadOnce(name)
    return MR:IsLoadOnce(name)
end

addon._pendingReloadModules = addon._pendingReloadModules or {}

function addon:ShouldDeferModuleDisable(name, moduleState)
    local L = addon.L

    if not self:IsModuleLoadOnce(name) then
        return false
    end

    if not moduleState or not (moduleState.initialized or moduleState.applied) then
        return false
    end

    if not self._pendingReloadModules[name] then
        self._pendingReloadModules[name] = true
    end

    return true
end

function MR:Refresh(name)
    local L = addon.L

    local info = self.modules[name]
    if not info then
        return false
    end

    local enabled = self:IsEnabled(name)
    local fn, useModuleSelf = ResolveRegistryFunction(info, enabled and "refresh" or "restore")

    -- Modules that install secure hooks cannot be cleanly unhooked during a live
    -- WoW session. Treat them as load-once: honor future config on reload, but do
    -- not run unsafe in-session teardown paths.
    if not enabled and info.loadOnce and info.module and (info.module.initialized or info.module.applied) then
        return true
    end

    if not fn then
        fn, useModuleSelf = ResolveRegistryFunction(info, enabled and "apply" or "restore")
    end

    if not fn then
        return false
    end

    local success, err
    if useModuleSelf then
        success, err = pcall(fn, info.module)
    else
        success, err = pcall(fn, addon)
    end

    if not success then
        addon:Error(L["ModuleRegistry: Refresh failed for"], name, "-", err)
    end

    return success
end

function MR:RefreshAll()
    local failed = {}
    self:EnsureLegacyRefreshTargets()

    for _, name in ipairs(self.loadOrder) do
        if not self:Refresh(name) then
            table.insert(failed, name)
        end
    end

    local legacyTargets = {}
    for name, info in pairs(self.legacyRefreshTargets) do
        table.insert(legacyTargets, { name = name, funcName = info.funcName, order = info.order })
    end
    table.sort(legacyTargets, function(a, b)
        return a.order < b.order
    end)

    for _, target in ipairs(legacyTargets) do
        local fn = addon[target.funcName]
        if type(fn) == "function" then
            local success, err = pcall(fn, addon)
            if not success then
                addon:Error(L["Legacy refresh failed for"], target.name, "-", err)
                table.insert(failed, target.name)
            end
        end
    end

    return failed
end

-- Enable a specific module
-- @param name: Module identifier
-- @return boolean success
function MR:Enable(name)
    local L = addon.L

    local info = self.modules[name]
    if not info then
        addon:Error(L["ModuleRegistry: Unknown module -"], name)
        return false
    end
    
    -- Update database
    if addon.db and addon.db.profile and addon.db.profile.modules then
        if not addon.db.profile.modules[name] then
            addon.db.profile.modules[name] = {}
        end
        addon.db.profile.modules[name].enabled = true
    end
    
    self:Refresh(name)
    
    addon:Debug(L["ModuleRegistry: Enabled -"], name)
    return true
end

-- Disable a specific module
-- @param name: Module identifier
-- @return boolean success
function MR:Disable(name)
    local L = addon.L

    local info = self.modules[name]
    if not info then
        addon:Error(L["ModuleRegistry: Unknown module -"], name)
        return false
    end
    
    -- Update database
    if addon.db and addon.db.profile and addon.db.profile.modules then
        if not addon.db.profile.modules[name] then
            addon.db.profile.modules[name] = {}
        end
        addon.db.profile.modules[name].enabled = false
    end
    
    -- hooksecurefunc / HookScript registrations are permanent for the session.
    -- Keep load-once modules active until reload instead of pretending we can fully disable them.
    if info.loadOnce and info.module and (info.module.initialized or info.module.applied) then
        return true
    end

    self:Refresh(name)
    
    addon:Debug(L["ModuleRegistry: Disabled -"], name)
    return true
end

-- Enable all registered modules (in load order)
function MR:EnableAll()
    for _, name in ipairs(self.loadOrder) do
        self:Enable(name)
    end
end

-- Disable all registered modules (in reverse load order for proper cleanup)
function MR:DisableAll()
    for i = #self.loadOrder, 1, -1 do
        self:Disable(self.loadOrder[i])
    end
end

-- Print status of all registered modules (for /dragonui status)
function MR:PrintStatus()
    local L = addon.L

    if #self.loadOrder == 0 then
        print("  " .. (L["No modules registered in ModuleRegistry"]))
        return
    end
    
    print("  |cFF00FF00" .. (L["Registered Modules:"]) .. "|r")
    for _, name in ipairs(self.loadOrder) do
        local info = self.modules[name]
        local enabled = self:IsEnabled(name)
        local status = enabled and ("|cFF00FF00" .. (L["Enabled"]) .. "|r") or ("|cFFFF0000" .. (L["Disabled"]) .. "|r")
        local loaded = info.module and (info.module.initialized or info.module.applied) and ("|cFF00FF00" .. (L["Loaded"]) .. "|r") or "|cFFAAAAAA-|r"
        
        local mode = info.loadOnce and (" |cFFFFD200(" .. (L["load-once"]) .. ")|r") or ""
        print(string.format("    %s: %s (%s)%s", info.displayName, status, loaded, mode))
    end
end

-- Convenience function for modules to register themselves
-- @param name: Module identifier
-- @param moduleTable: Module state table
-- @param displayName: Display name (optional)
-- @param description: Description (optional)
function addon:RegisterModule(name, moduleTable, displayName, description, options)
    return MR:Register(name, moduleTable, displayName, description, options)
end

-- No external callers: DEFAULT_LEGACY_REFRESH_TARGETS covers the three frames that need it. Kept as the
-- supported way to add one without editing this file.
function addon:RegisterLegacyRefreshTarget(name, funcName, order)
    return MR:RegisterLegacyRefreshTarget(name, funcName, order)
end

function addon:RefreshRegisteredSystems()
    return MR:RefreshAll()
end

-- ============================================================================
-- COMBAT QUEUE SYSTEM
-- ============================================================================
-- Central system for deferring operations that cannot run during combat lockdown.
-- Pattern: Check InCombatLockdown() -> if true, queue operation -> execute after combat
-- Reference: common PLAYER_REGEN_ENABLED deferred-execution pattern

addon.CombatQueue = addon.CombatQueue or {
    -- Pending operations table: { [id] = { func, args } }
    pending = {},
    -- Is the event frame registered?
    isRegistered = false,
    -- Event frame for PLAYER_REGEN_ENABLED
    eventFrame = nil,
}

local CQ = addon.CombatQueue

-- Initialize the combat queue event frame
local function InitializeCombatQueueFrame()
    if CQ.eventFrame then return end
    
    CQ.eventFrame = CreateFrame("Frame", "DragonUI_CombatQueueFrame", UIParent)
    CQ.eventFrame:Hide()
    CQ.eventFrame:SetScript("OnEvent", function(self, event)
        if event == "PLAYER_REGEN_ENABLED" then
            addon.CombatQueue:ProcessQueue()
        end
    end)
end

-- Add an operation to the combat queue
-- @param id: Unique identifier for this operation (prevents duplicates)
-- @param func: Function to call when combat ends
-- @param ...: Arguments to pass to the function
function CQ:Add(id, func, ...)
    local L = addon.L

    if not id or not func then
        addon:Error(L["CombatQueue:Add requires id and func"])
        return false
    end
    
    -- Initialize frame if needed
    InitializeCombatQueueFrame()
    
    -- Store the operation with its arguments
    self.pending[id] = { func = func, args = {...} }
    
    -- Register for PLAYER_REGEN_ENABLED if not already
    if not self.isRegistered then
        self.eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
        self.isRegistered = true
        addon:Debug(L["CombatQueue: Registered PLAYER_REGEN_ENABLED"])
    end
    
    addon:Debug(L["CombatQueue: Queued operation -"], id)
    return true
end

-- Remove an operation from the queue (if no longer needed)
-- @param id: Identifier of the operation to remove
function CQ:Remove(id)
    local L = addon.L

    if self.pending[id] then
        self.pending[id] = nil
        addon:Debug(L["CombatQueue: Removed operation -"], id)
    end
    
    -- If queue is empty, unregister the event
    if not next(self.pending) and self.isRegistered then
        self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self.isRegistered = false
    end
end

-- Check if an operation is in the queue
-- @param id: Identifier to check
function CQ:HasPending(id)
    return self.pending[id] ~= nil
end

-- Process all queued operations (called on PLAYER_REGEN_ENABLED)
function CQ:ProcessQueue()
    local L = addon.L

    addon:Debug(L["CombatQueue: Processing"], addon:tcount(self.pending), L["queued operations"])
    
    -- Process all pending operations
    for id, operation in pairs(self.pending) do
        local success, err = pcall(function()
            operation.func(unpack(operation.args))
        end)
        
        if not success then
            addon:Error(L["CombatQueue: Failed to execute"], id, "-", err)
        else
            addon:Debug(L["CombatQueue: Executed -"], id)
        end
    end
    
    -- Clear all pending operations
    self.pending = {}
    
    -- Unregister the event
    if self.isRegistered then
        self.eventFrame:UnregisterEvent("PLAYER_REGEN_ENABLED")
        self.isRegistered = false
        addon:Debug(L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"])
    end
end

-- Execute immediately if out of combat, queue if in combat
-- @param id: Unique identifier for this operation
-- @param func: Function to call
-- @param ...: Arguments to pass to the function
-- @return true if executed immediately, false if queued
function CQ:ExecuteOrQueue(id, func, ...)
    local L = addon.L

    if InCombatLockdown() then
        self:Add(id, func, ...)
        return false
    else
        -- Execute immediately
        local args = {...}
        local success, err = pcall(function()
            func(unpack(args))
        end)
        
        if not success then
            addon:Error(L["CombatQueue: Immediate execution failed -"], id, "-", err)
        end
        return true
    end
end

-- Convenience function for modules to check and queue
-- Returns true if operation can proceed (not in combat)
-- @param moduleId: Module name for the queue ID
-- @param operationName: Name of the operation (combined with moduleId)
-- @param func: Function to call when combat ends
-- @param ...: Arguments
function addon:SafeExecute(moduleId, operationName, func, ...)
    local queueId = moduleId .. "_" .. operationName
    return CQ:ExecuteOrQueue(queueId, func, ...)
end

-- ============================================================================
-- MODULE HELPERS (centralized — replaces per-module boilerplate)
-- ============================================================================

-- No-op function reusable across all modules (avoids multiple definitions)

-- Get module config from addon.db.profile.modules[moduleName]
-- @param moduleName: string key matching database.lua modules table
-- @return table or nil
function addon:GetModuleConfig(moduleName)
    return self.db and self.db.profile and self.db.profile.modules
        and self.db.profile.modules[moduleName]
end

-- Check if a module is enabled in the database
-- @param moduleName: string key matching database.lua modules table
-- @return boolean
function addon:IsModuleEnabled(moduleName)
    local cfg = self:GetModuleConfig(moduleName)
    return cfg and cfg.enabled or false
end

-- ============================================================================
-- DELAYED EXECUTION (unified timer — replaces 3 different implementations)
-- ============================================================================

-- Frame pool for delayed execution (C_Timer replacement for 3.3.5a)
addon._timerPool = addon._timerPool or {}

-- Schedule a callback after a delay (seconds)
-- @param delay: number — seconds to wait
-- @param callback: function — called after delay
function addon:After(delay, callback)
    if type(callback) ~= "function" then
        return
    end

    delay = tonumber(delay) or 0
    if delay < 0 then
        delay = 0
    end

    local f = tremove(self._timerPool) or CreateFrame("Frame")
    f._elapsed = 0
    f._delay = delay
    f._callback = callback
    f:SetScript("OnUpdate", function(self, dt)
        self._elapsed = self._elapsed + dt
        if self._elapsed >= self._delay then
            self:SetScript("OnUpdate", nil)
            tinsert(addon._timerPool, self)
            local cb = self._callback
            self._callback = nil
            cb()
        end
    end)
end

function addon:SafeSetAtlas(texture, atlasName, useAtlasSize)
    if not texture or not atlasName then
        return false
    end

    if texture.set_atlas then
        local ok = pcall(texture.set_atlas, texture, atlasName, useAtlasSize)
        return ok
    end

    return false
end

function addon:SafeSetTexture(texture, path, fallback)
    if not texture then
        return false
    end

    if path and path ~= "" then
        texture:SetTexture(path)
        return true
    end

    if fallback and fallback ~= "" then
        texture:SetTexture(fallback)
        return true
    end

    texture:SetTexture(nil)
    return false
end

function addon:ApplyDatabaseMigrations()
    if not self.db or not self.db.profile then
        return
    end

    local profile = self.db.profile
    local currentVersion = tonumber(profile.version) or 0

    if currentVersion < self.DB_SCHEMA_VERSION then
        ApplyMissingDefaults(self.defaults.profile, profile)
    end

    -- Combuctor → Bagster rename. AceDB already rawset a default `bagster` table at :New, so we
    -- can't gate on it being nil; the old `combuctor` table is the source of truth when present.
    local modules = rawget(profile, "modules")
    if modules then
        local oldC = rawget(modules, "combuctor")
        if oldC ~= nil then
            if type(oldC) == "table" and type(rawget(modules, "bagster")) == "table" then
                addon.DeepCopy(oldC, modules.bagster) -- user values win, defaults fill gaps
            else
                modules.bagster = oldC
            end
            modules.combuctor = nil
        end
    end

    -- profile.chat had no readers left; clear stored values now that the default is gone.
    if rawget(profile, "chat") ~= nil then
        profile.chat = nil
    end

    -- Extra bar slots moved to db.char; drop the profile-wide leftovers so alts stop inheriting them.
    local additional = rawget(profile, "additional")
    local extrabar1 = additional and rawget(additional, "extrabar1")
    if extrabar1 then
        extrabar1.slots = nil
    end

    local global = self.db.global
    if global then
        local oldCache = rawget(global, "combuctorCache")
        if oldCache ~= nil then
            if type(oldCache) == "table" and type(rawget(global, "bagsterCache")) == "table" then
                addon.DeepCopy(oldCache, global.bagsterCache)
            else
                global.bagsterCache = oldCache
            end
            global.combuctorCache = nil
        end
    end

    profile.version = self.DB_SCHEMA_VERSION
    self.db.version = self.DB_SCHEMA_VERSION
end

-- ============================================================================
-- PRINT / DEBUG UTILITIES
-- ============================================================================

-- Print a formatted message
function addon:Print(...)
    print("|cFF00FF00[DragonUI]|r", ...)
end

-- Print a debug message (only in debug mode)
function addon:Debug(...)
    if addon.debugMode then
        print("|cFFFFFF00[DragonUI Debug]|r", ...)
    end
end

-- Print an error message
function addon:Error(...)
    print("|cFFFF0000[DragonUI Error]|r", ...)
end
