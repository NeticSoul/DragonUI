--[[
================================================================================
DragonUI - Position Presets (Edit Mode)
================================================================================
Save, load, export and import element positions edited via /duiedit without
touching scales, colors, or other module settings.
================================================================================
]]

local addon = select(2, ...)
local L = addon.L

local PositionPresets = {}
addon.PositionPresets = PositionPresets

local SNAPSHOT_VERSION = 1
local EXPORT_HEADER = "!DUIPP1!"
local PANEL_WIDGET_KEY = "positionPresetPanel"

local WIDGET_POSITION_KEYS = {
    anchor = true,
    posX = true,
    posY = true,
    custom_position = true,
}

local CASTBAR_POSITION_KEYS = {
    override = true,
    x_position = true,
    y_position = true,
    anchor = true,
    anchorParent = true,
    anchorFrame = true,
}

local UNITFRAME_POSITION_KEYS = {
    override = true,
    x = true,
    y = true,
    anchor = true,
    anchorParent = true,
    anchorFrame = true,
}

local CASTBAR_PLAYER_POSITION_KEYS = {
    x_position = true,
    y_position = true,
}

local QUESTTRACKER_POSITION_KEYS = {
    anchor = true,
    x = true,
    y = true,
}

local LOOTROLL_POSITION_KEYS = {
    anchor = true,
    x = true,
    y = true,
}

local TOTEM_POSITION_KEYS = {
    x_position = true,
    y_offset = true,
    manual_position = true,
}

local STANCE_POSITION_KEYS = {
    x_position = true,
    y_offset = true,
}

local Serializer = {}
LibStub("AceSerializer-3.0"):Embed(Serializer)
local LibDeflate = LibStub("LibDeflate")

-- ============================================================================
-- HELPERS
-- ============================================================================

local function PickFields(source, fieldMap)
    if type(source) ~= "table" or type(fieldMap) ~= "table" then
        return nil
    end

    local result = {}
    for key in pairs(fieldMap) do
        if source[key] ~= nil then
            result[key] = source[key]
        end
    end

    return next(result) and result or nil
end

local function CopyTable(source)
    if addon.DeepCopy then
        return addon.DeepCopy(source)
    end
    if addon.CopyTable then
        return addon:CopyTable(source)
    end
    return source
end

local function MergeFields(target, source, fieldMap)
    if type(source) ~= "table" then
        return
    end

    for key, value in pairs(source) do
        if not fieldMap or fieldMap[key] then
            target[key] = value
        end
    end
end

local function CalculateQuadrantPoint(frame)
    local screenWidth = UIParent:GetRight()
    local screenHeight = UIParent:GetTop()
    local screenCenterX = UIParent:GetCenter()
    local cx, cy = frame:GetCenter()

    if not cx or not cy or not screenWidth or not screenHeight or not screenCenterX then
        return nil
    end

    local LEFT = screenWidth / 3
    local RIGHT = screenWidth * 2 / 3
    local TOP = screenHeight / 2
    local point, x, y

    if cy >= TOP then
        point = "TOP"
        y = -(screenHeight - frame:GetTop())
    else
        point = "BOTTOM"
        y = frame:GetBottom()
    end

    if cx >= RIGHT then
        point = point .. "RIGHT"
        x = frame:GetRight() - screenWidth
    elseif cx <= LEFT then
        point = point .. "LEFT"
        x = frame:GetLeft()
    else
        x = cx - screenCenterX
    end

    return point, math.floor(x + 0.5), math.floor(y + 0.5)
end

local function SaveQuadrantSection(frame, sectionName)
    if not frame or not addon.db or not addon.db.profile then
        return
    end

    local point, x, y = CalculateQuadrantPoint(frame)
    if not point then
        return
    end

    addon.db.profile[sectionName] = addon.db.profile[sectionName] or {}
    local section = addon.db.profile[sectionName]
    section.anchor = point
    section.x = x
    section.y = y
end

function PositionPresets:GetStore()
    if not addon.db or not addon.db.profile then
        return {}
    end

    if not addon.db.profile.positionPresets then
        addon.db.profile.positionPresets = {}
    end

    return addon.db.profile.positionPresets
end

function PositionPresets:GetSortedNames()
    local names = {}
    for name in pairs(self:GetStore()) do
        names[#names + 1] = name
    end
    table.sort(names)
    return names
end

function PositionPresets:UniqueName(baseName)
    local store = self:GetStore()
    if not store[baseName] then
        return baseName
    end

    local index = 2
    while store[baseName .. " (" .. index .. ")"] do
        index = index + 1
    end

    return baseName .. " (" .. index .. ")"
end

-- ============================================================================
-- FLUSH / SNAPSHOT / RESTORE
-- ============================================================================

local function ShouldFlushWidgetConfigPath(frameData)
    if not frameData.configPath or #frameData.configPath ~= 2 then
        return false
    end

    local section, key = frameData.configPath[1], frameData.configPath[2]
    local profile = addon.db and addon.db.profile

    if section == "additional" then
        return false
    end

    if section ~= "widgets" then
        return true
    end

    if key == "tot" or key == "fot" then
        local cfg = profile and profile.unitframe and profile.unitframe[key]
        return cfg and cfg.override
    end

    if key == "targetCastbar" then
        local cfg = profile and profile.castbar and profile.castbar.target
        return cfg and cfg.override
    end

    if key == "focusCastbar" then
        local cfg = profile and profile.castbar and profile.castbar.focus
        return cfg and cfg.override
    end

    return true
end

local function ShouldSnapshotWidgetKey(key, profile)
    if key == PANEL_WIDGET_KEY then
        return false
    end

    if key == "tot" or key == "fot" then
        local cfg = profile.unitframe and profile.unitframe[key]
        return cfg and cfg.override
    end

    if key == "targetCastbar" then
        local cfg = profile.castbar and profile.castbar.target
        return cfg and cfg.override
    end

    if key == "focusCastbar" then
        local cfg = profile.castbar and profile.castbar.focus
        return cfg and cfg.override
    end

    return true
end

local function ResetDetachedWidgetDefaults(profile, widgetKey)
    if not profile.widgets then
        return
    end

    local defaults = addon.defaults and addon.defaults.profile and addon.defaults.profile.widgets
    if defaults and defaults[widgetKey] then
        if addon.CopyTable then
            profile.widgets[widgetKey] = addon:CopyTable(defaults[widgetKey])
        else
            profile.widgets[widgetKey] = CopyTable(defaults[widgetKey])
        end
    else
        profile.widgets[widgetKey] = nil
    end
end

local function FlushAdditionalEditorPosition(frameData)
    local frame = frameData.frame
    if not frame then
        return
    end

    local key = frameData.configPath and frameData.configPath[2]
    if key == "stance" and frame.SyncManualOverlayDeltaToStanceConfig then
        frame:SyncManualOverlayDeltaToStanceConfig()
    end
end

function PositionPresets:FlushEditorPositions()
    if addon.EditorMode and addon.EditorMode.FlushPositions then
        addon.EditorMode:FlushPositions()
    end

    for name, frameData in pairs(addon.EditableFrames or {}) do
        local frame = frameData.frame
        local isShown = frame and frame:IsShown()

        if isShown and frameData.onHide then
            pcall(frameData.onHide)
        end

        if isShown and frameData.configPath and frameData.configPath[1] == "additional" then
            pcall(FlushAdditionalEditorPosition, frameData)
        elseif isShown and frameData.configPath and ShouldFlushWidgetConfigPath(frameData) then
            if #frameData.configPath == 2 then
                addon.SaveUIFramePosition(frame, frameData.configPath[1], frameData.configPath[2])
            else
                addon.SaveUIFramePosition(frame, frameData.configPath[1])
            end
        elseif isShown and name == "questtracker" then
            SaveQuadrantSection(frame, "questtracker")
        elseif isShown and name == "lootroll" then
            SaveQuadrantSection(frame, "lootroll")
        end
    end
end

function PositionPresets:Snapshot()
    self:FlushEditorPositions()

    local profile = addon.db and addon.db.profile
    if not profile then
        return nil
    end

    local snapshot = {
        version = SNAPSHOT_VERSION,
        widgets = {},
        questtracker = PickFields(profile.questtracker, QUESTTRACKER_POSITION_KEYS),
        lootroll = PickFields(profile.lootroll, LOOTROLL_POSITION_KEYS),
        castbar = {},
        unitframe = {},
        additional = {},
    }

    if profile.widgets then
        for key, widgetCfg in pairs(profile.widgets) do
            if ShouldSnapshotWidgetKey(key, profile) then
                local picked = PickFields(widgetCfg, WIDGET_POSITION_KEYS)
                if picked then
                    snapshot.widgets[key] = picked
                end
            end
        end
    end

    if profile.castbar then
        local playerCast = PickFields(profile.castbar, CASTBAR_PLAYER_POSITION_KEYS)
        if playerCast then
            snapshot.castbar.player = playerCast
        end

        for _, key in ipairs({ "target", "focus" }) do
            local picked = PickFields(profile.castbar[key], CASTBAR_POSITION_KEYS)
            if picked then
                snapshot.castbar[key] = picked
            end
        end
    end

    if profile.unitframe then
        for _, key in ipairs({ "tot", "fot", "party" }) do
            local picked = PickFields(profile.unitframe[key], UNITFRAME_POSITION_KEYS)
            if picked then
                snapshot.unitframe[key] = picked
            end
        end
    end

    if profile.additional then
        local totem = PickFields(profile.additional.totem, TOTEM_POSITION_KEYS)
        if totem then
            snapshot.additional.totem = totem
        end

        local stance = PickFields(profile.additional.stance, STANCE_POSITION_KEYS)
        if stance then
            snapshot.additional.stance = stance
        end
    end

    return snapshot
end

function PositionPresets:Restore(snapshot)
    if type(snapshot) ~= "table" then
        return false
    end

    local profile = addon.db and addon.db.profile
    if not profile then
        return false
    end

    if type(snapshot.questtracker) == "table" then
        profile.questtracker = profile.questtracker or {}
        MergeFields(profile.questtracker, snapshot.questtracker, QUESTTRACKER_POSITION_KEYS)
    end

    if type(snapshot.lootroll) == "table" then
        profile.lootroll = profile.lootroll or {}
        MergeFields(profile.lootroll, snapshot.lootroll, LOOTROLL_POSITION_KEYS)
    end

    if type(snapshot.castbar) == "table" then
        profile.castbar = profile.castbar or {}
        if type(snapshot.castbar.player) == "table" then
            MergeFields(profile.castbar, snapshot.castbar.player, CASTBAR_PLAYER_POSITION_KEYS)
        end
        for key, castCfg in pairs(snapshot.castbar) do
            if key ~= "player" then
                profile.castbar[key] = profile.castbar[key] or {}
                MergeFields(profile.castbar[key], castCfg, CASTBAR_POSITION_KEYS)
            end
        end
        if snapshot.castbar.target then
            if snapshot.castbar.target.override == true then
                profile.castbar.target.override = true
            else
                profile.castbar.target.override = false
                ResetDetachedWidgetDefaults(profile, "targetCastbar")
            end
        end
        if snapshot.castbar.focus then
            if snapshot.castbar.focus.override == true then
                profile.castbar.focus.override = true
            else
                profile.castbar.focus.override = false
                ResetDetachedWidgetDefaults(profile, "focusCastbar")
            end
        end
    end

    if type(snapshot.unitframe) == "table" then
        profile.unitframe = profile.unitframe or {}
        for key, unitCfg in pairs(snapshot.unitframe) do
            profile.unitframe[key] = profile.unitframe[key] or {}
            MergeFields(profile.unitframe[key], unitCfg, UNITFRAME_POSITION_KEYS)
            if key == "tot" or key == "fot" then
                if unitCfg.override == true then
                    profile.unitframe[key].override = true
                else
                    profile.unitframe[key].override = false
                    ResetDetachedWidgetDefaults(profile, key)
                end
            end
        end
    end

    if type(snapshot.widgets) == "table" then
        profile.widgets = profile.widgets or {}
        for key, widgetCfg in pairs(snapshot.widgets) do
            if ShouldSnapshotWidgetKey(key, profile) then
                profile.widgets[key] = profile.widgets[key] or {}
                MergeFields(profile.widgets[key], widgetCfg, WIDGET_POSITION_KEYS)
            end
        end
    end

    if type(snapshot.additional) == "table" then
        profile.additional = profile.additional or {}
        if type(snapshot.additional.totem) == "table" then
            profile.additional.totem = profile.additional.totem or {}
            MergeFields(profile.additional.totem, snapshot.additional.totem, TOTEM_POSITION_KEYS)
        end
        if type(snapshot.additional.stance) == "table" then
            profile.additional.stance = profile.additional.stance or {}
            MergeFields(profile.additional.stance, snapshot.additional.stance, STANCE_POSITION_KEYS)
        end
    end

    return true
end

local function SyncMicromenuEditorAnchor(frameData)
    local menu = frameData and frameData.blizzardFrame
    if not menu or not menu.editorFrame then
        return
    end

    local offX = menu.editorOffX or 0
    local offY = menu.editorOffY or 0
    menu:ClearAllPoints()
    menu:SetPoint("BOTTOMRIGHT", menu.editorFrame, "CENTER", offX, offY)
end

local function SyncBagsbarEditorAnchor(frameData)
    local bagsFrame = frameData and frameData.frame
    local backpack = frameData and frameData.blizzardFrame
    if not bagsFrame or not backpack then
        return
    end

    backpack:ClearAllPoints()
    backpack:SetPoint("RIGHT", bagsFrame, "RIGHT", 0, 0)
end

local function ApplyEditableWidgetOverlays()
    if not addon.ApplyWidgetPositionFromDB then
        return
    end

    for name, frameData in pairs(addon.EditableFrames or {}) do
        if frameData.frame and ShouldFlushWidgetConfigPath(frameData) then
            local widgetKey = name
            if frameData.configPath and #frameData.configPath == 2 then
                widgetKey = frameData.configPath[2]
            end
            addon.ApplyWidgetPositionFromDB(widgetKey, frameData.frame)
            if name == "micromenu" then
                SyncMicromenuEditorAnchor(frameData)
            elseif name == "bagsbar" then
                SyncBagsbarEditorAnchor(frameData)
            end
        end
    end

    if addon.MinimapModule and addon.MinimapModule.lfgWrapper then
        addon.ApplyWidgetPositionFromDB("lfgframe", addon.MinimapModule.lfgWrapper)
    end
end

local function ClearEditorAttachFlags(frame)
    if not frame then
        return
    end

    frame.DragonUI_WasDragged = nil
    frame.DragonUI_WasAdjustedByEditor = nil
end

local function ApplySmallFrameAttachState(configKey, refreshFn)
    local frameData = addon.EditableFrames and addon.EditableFrames[configKey]
    local module = frameData and frameData.module
    if not module or not module.anchorFrame or not module.ApplyWidgetPosition then
        if refreshFn then
            refreshFn()
        end
        return
    end

    ClearEditorAttachFlags(module.anchorFrame)

    local profile = addon.db and addon.db.profile
    local unitCfg = profile and profile.unitframe and profile.unitframe[configKey]

    module:ApplyWidgetPosition()

    if unitCfg and unitCfg.override and module.UpdateWidgets then
        module:UpdateWidgets()
    elseif refreshFn then
        refreshFn()
    end
end

local function ApplyCastbarAttachStates()
    for _, frameName in ipairs({ "TargetCastbar", "FocusCastbar" }) do
        local frameData = addon.EditableFrames and addon.EditableFrames[frameName]
        ClearEditorAttachFlags(frameData and frameData.frame)
    end

    if addon.ApplyCastbarWidgetPositions then
        addon.ApplyCastbarWidgetPositions()
    end

    if addon.RefreshTargetCastbar then
        addon.RefreshTargetCastbar()
    end
    if addon.RefreshFocusCastbar then
        addon.RefreshFocusCastbar()
    end
end

local function ApplyDetachableAttachStates()
    ApplySmallFrameAttachState("tot", function()
        if addon.RefreshToTFrame then
            addon:RefreshToTFrame()
        end
    end)

    ApplySmallFrameAttachState("fot", function()
        if addon.RefreshToFFrame then
            addon:RefreshToFFrame()
        end
    end)

    ApplyCastbarAttachStates()
end

function PositionPresets:ApplyStoredPositions()
    addon._positionPresetApply = true
    local ok, err = pcall(function()
        ApplyDetachableAttachStates()

        if addon.ApplyActionBarPositions then
            addon.ApplyActionBarPositions()
        end

        if addon.RefreshCastbar then
            addon.RefreshCastbar()
        end

        ApplyEditableWidgetOverlays()

        ApplyDetachableAttachStates()

        if addon.UpdatePetbarPosition then
            addon.UpdatePetbarPosition()
        end
        if addon.UpdateStanceBarPosition then
            addon.UpdateStanceBarPosition()
        end
        if addon.UpdateVehicleExitPosition then
            addon.UpdateVehicleExitPosition()
        end

        if addon.RefreshMulticast then
            addon.RefreshMulticast(true)
        end

        if addon.RefreshQuestTracker then
            addon.RefreshQuestTracker()
        end

        if addon.RefreshLootRoll then
            addon.RefreshLootRoll()
        elseif addon.LootRollModule and addon.LootRollModule.ApplySystem then
            addon.LootRollModule:ApplySystem()
        end

        if addon.ApplyErrorMessagesPosition then
            addon.ApplyErrorMessagesPosition()
        end

        if addon.RefreshBuffFrame then
            addon:RefreshBuffFrame()
        end

        if addon.RefreshPartyFrames then
            addon:RefreshPartyFrames()
        end

        if addon.RefreshMinimap then
            addon:RefreshMinimap()
        end

        local MR = addon.ModuleRegistry
        if MR and MR.RefreshAll then
            MR:RefreshAll()
        end
    end)

    addon._positionPresetApply = nil

    if not ok then
        addon:Error("PositionPresets:ApplyStoredPositions failed", err)
        return false
    end

    return true
end

local function SyncAttachedSmallFrameOverlay(configKey)
    local frameData = addon.EditableFrames and addon.EditableFrames[configKey]
    if not frameData or not frameData.frame then
        return
    end

    local profile = addon.db and addon.db.profile
    local unitCfg = profile and profile.unitframe and profile.unitframe[configKey]
    if unitCfg and unitCfg.override then
        return
    end

    local mainFrame
    if configKey == "tot" and TargetFrameToT then
        mainFrame = TargetFrameToT
    elseif configKey == "fot" and FocusFrameToT then
        mainFrame = FocusFrameToT
    end

    if not mainFrame then
        return
    end

    local fx, fy = mainFrame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if not (fx and fy and ux and uy) then
        return
    end

    frameData.frame:ClearAllPoints()
    frameData.frame:SetPoint("CENTER", UIParent, "CENTER", fx - ux, fy - uy)
end

function PositionPresets:RefreshEditorOverlays()
    for _, frameData in pairs(addon.EditableFrames or {}) do
        if not frameData.frame or not frameData.frame:IsShown() then
            -- skip hidden overlays
        elseif frameData.editorVisible and not frameData.editorVisible() then
            -- skip disabled editor entries
        else
            if frameData.name == "tot" or frameData.name == "fot" then
                SyncAttachedSmallFrameOverlay(frameData.name)
            end

            if frameData.showTest then
                local ok, err = pcall(frameData.showTest)
                if not ok and addon.Debug then
                    addon:Debug("Position preset showTest failed:", frameData.name or "?", err)
                end
            end
        end
    end
end

function PositionPresets:Apply()
    if InCombatLockdown() then
        addon:Print(L["Cannot move frames during combat!"])
        return false
    end

    if not self:ApplyStoredPositions() then
        return false
    end

    if addon.EditorMode and addon.EditorMode:IsActive() then
        self:RefreshEditorOverlays()

        if addon.UpdateOverlaySizes then
            addon.UpdateOverlaySizes()
        end

        if addon.DeselectEditorFrame then
            addon.DeselectEditorFrame()
        end

        self:RefreshPanel()
    end

    return true
end

function PositionPresets:Save(name)
    if not name or name == "" then
        return false
    end

    name = strtrim(name):gsub("|", "")
    if name == "" then
        return false
    end

    local snapshot = self:Snapshot()
    if not snapshot then
        return false
    end

    local store = self:GetStore()
    store[name] = {
        data = snapshot,
        date = date("%Y-%m-%d %H:%M"),
    }

    return true
end

function PositionPresets:Load(name)
    local store = self:GetStore()
    local entry = store[name]
    if not entry or not entry.data then
        return false
    end

    if not self:Restore(entry.data) then
        return false
    end

    return self:Apply()
end

function PositionPresets:Delete(name)
    local store = self:GetStore()
    if not store[name] then
        return false
    end

    store[name] = nil
    return true
end

function PositionPresets:ExportToString(name)
    local store = self:GetStore()
    local entry = store[name]
    if not entry or not entry.data then
        return nil
    end

    local serialized = Serializer:Serialize(entry.data)
    if not serialized then
        return nil
    end

    local compressed = LibDeflate:CompressDeflate(serialized)
    if not compressed then
        return nil
    end

    local encoded = LibDeflate:EncodeForPrint(compressed)
    if not encoded then
        return nil
    end

    return EXPORT_HEADER .. encoded
end

function PositionPresets:ImportFromString(str)
    if type(str) ~= "string" then
        return nil, "empty"
    end

    str = strtrim(str)
    if str == "" then
        return nil, "empty"
    end

    if str:sub(1, #EXPORT_HEADER) ~= EXPORT_HEADER then
        return nil, "header"
    end

    local payload = str:sub(#EXPORT_HEADER + 1)
    if payload == "" then
        return nil, "payload"
    end

    local decoded = LibDeflate:DecodeForPrint(payload)
    if not decoded then
        return nil, "decode"
    end

    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then
        return nil, "decompress"
    end

    local ok, data = Serializer:Deserialize(decompressed)
    if not ok or type(data) ~= "table" or data.version ~= SNAPSHOT_VERSION then
        return nil, "deserialize"
    end

    return data
end

-- ============================================================================
-- STATIC POPUPS (load / delete / import name only)
-- ============================================================================

StaticPopupDialogs["DRAGONUI_POSITION_PRESET_LOAD"] = {
    text = L["Load position preset '%s'? This will overwrite your current element positions."],
    button1 = L["Load"],
    button2 = L["Cancel"],
    OnAccept = function(self)
        local name = self.data
        if name and PositionPresets:Load(name) then
            addon:Print("|cFF00FF00[DragonUI]|r " .. L["Position preset loaded: "] .. name)
            PositionPresets:RefreshPanel()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

StaticPopupDialogs["DRAGONUI_POSITION_PRESET_DELETE"] = {
    text = L["Delete position preset '%s'? This cannot be undone."],
    button1 = L["Delete"],
    button2 = L["Cancel"],
    OnAccept = function(self)
        local name = self.data
        if name and PositionPresets:Delete(name) then
            addon:Print("|cFF00FF00[DragonUI]|r " .. L["Position preset deleted: "] .. name)
            PositionPresets:RefreshPanel()
        end
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

StaticPopupDialogs["DRAGONUI_POSITION_PRESET_IMPORT_NAME"] = {
    text = "",
    button1 = "",
    button2 = "",
    hasEditBox = true,
    maxLetters = 40,
    OnShow = function(self)
        self.text:SetText(L["Enter a name for the imported position preset:"])
        self.button1:SetText(L["Save"])
        self.button2:SetText(L["Cancel"])

        local editBox = self.editBox or _G[self:GetName() .. "EditBox"]
        if editBox then
            editBox:SetText(PositionPresets:UniqueName(L["Imported Position Preset"]))
            editBox:HighlightText()
            editBox:SetFocus()
        end
    end,
    OnAccept = function(self)
        local editBox = self.editBox or _G[self:GetName() .. "EditBox"]
        local name = editBox and editBox:GetText() and strtrim(editBox:GetText())
        if not name or name == "" then
            return
        end

        name = name:gsub("|", "")
        if name == "" then
            return
        end

        local importedData = self.data
        if type(importedData) ~= "table" then
            return
        end

        local store = PositionPresets:GetStore()
        store[name] = {
            data = CopyTable(importedData),
            date = date("%Y-%m-%d %H:%M"),
        }

        addon:Print("|cFF00FF00[DragonUI]|r " .. L["Position preset imported: "] .. name)
        PositionPresets:RefreshPanel()
    end,
    EditBoxOnEnterPressed = function(self)
        local parent = self:GetParent()
        StaticPopupDialogs["DRAGONUI_POSITION_PRESET_IMPORT_NAME"].OnAccept(parent)
        parent:Hide()
    end,
    EditBoxOnEscapePressed = function(self)
        self:GetParent():Hide()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = 1,
    preferredIndex = 3,
}

-- ============================================================================
-- IN-GAME PANEL (Edit Mode) — collapsible, preset list, inline name field
-- ============================================================================

local presetPanel
local presetRows = {}
local importExportFrame
local menuExpanded = false

local EDITOR_UI_STRATA = "TOOLTIP"
local EDITOR_UI_LEVEL = 1000
local PANEL_WIDTH = 220
local HEADER_HEIGHT = 28
local ROW_HEIGHT = 22
local SAVE_ROW_HEIGHT = 24
local FOOTER_HEIGHT = 22
local PANEL_PADDING = 8
local SCROLLBAR_WIDTH = 24
local MAX_LIST_HEIGHT = 110
local CONTENT_WIDTH = PANEL_WIDTH - (PANEL_PADDING * 2)
local LIST_WIDTH = CONTENT_WIDTH - SCROLLBAR_WIDTH
-- TOP offset when collapsed: CENTER y=130 + half header height
local PANEL_TOP_OFFSET = 130 + (HEADER_HEIGHT / 2)

local BD_PANEL = {
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 },
}

local function StylePanelButton(button)
    if addon.StyleEditorButton then
        addon.StyleEditorButton(button)
    end
    if button.GetParent and button:GetParent() then
        button:SetFrameLevel(button:GetParent():GetFrameLevel() + 5)
    end
end

local function GetImportExportFrame()
    if importExportFrame then
        return importExportFrame
    end

    local frame = CreateFrame("Frame", "DragonUI_PositionPresetImportExport", UIParent)
    frame:SetSize(500, 350)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("FULLSCREEN_DIALOG")
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 11, top = 12, bottom = 10 },
    })
    frame:Hide()
    tinsert(UISpecialFrames, "DragonUI_PositionPresetImportExport")

    frame.title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.title:SetPoint("TOP", 0, -16)

    local ieScroll = CreateFrame("ScrollFrame", "DragonUI_PositionPresetIEScroll", frame, "UIPanelScrollFrameTemplate")
    ieScroll:SetPoint("TOPLEFT", 20, -45)
    ieScroll:SetPoint("BOTTOMRIGHT", -40, 50)

    local editBox = CreateFrame("EditBox", "DragonUI_PositionPresetIEEditBox", ieScroll)
    editBox:SetMultiLine(true)
    editBox:SetAutoFocus(false)
    editBox:SetFontObject(ChatFontNormal)
    editBox:SetWidth(ieScroll:GetWidth() or 430)
    editBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        frame:Hide()
    end)
    ieScroll:SetScrollChild(editBox)
    frame.editBox = editBox

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    frame.btn1 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.btn1:SetSize(120, 24)
    frame.btn1:SetPoint("BOTTOMLEFT", 20, 16)

    frame.btn2 = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    frame.btn2:SetSize(120, 24)
    frame.btn2:SetPoint("BOTTOMRIGHT", -20, 16)
    frame.btn2:SetText(L["Cancel"])
    frame.btn2:SetScript("OnClick", function()
        frame:Hide()
    end)

    importExportFrame = frame
    return frame
end

local function ShowExportFrame(presetName, exportString)
    local frame = GetImportExportFrame()
    frame.title:SetText(L["Export Position Preset"])
    frame.editBox:SetText(exportString)
    frame.editBox:SetScript("OnTextChanged", function(self, userInput)
        -- Keep export payload read-only without risking recursive SetText loops.
        if userInput and self:GetText() ~= exportString then
            self:SetText(exportString)
            self:HighlightText()
        end
    end)
    frame.editBox:SetCursorPosition(0)
    frame.btn1:SetText(L["Select All"])
    frame.btn1:SetScript("OnClick", function()
        frame.editBox:SetFocus()
        frame.editBox:HighlightText()
    end)
    frame:Show()
    frame.editBox:SetFocus()
    frame.editBox:HighlightText()
end

local function ShowImportFrame()
    local frame = GetImportExportFrame()
    frame.title:SetText(L["Import Position Preset"])
    frame.editBox:SetText("")
    frame.editBox:SetScript("OnTextChanged", nil)
    frame.btn1:SetText(L["Import"])
    frame.btn1:SetScript("OnClick", function()
        local text = strtrim(frame.editBox:GetText())
        if text == "" then
            return
        end

        local data, errType = PositionPresets:ImportFromString(text)
        if not data then
            local msg = L["Invalid position preset string."]
            if errType == "header" then
                msg = L["Not a valid DragonUI position preset string."]
            end
            addon:Print("|cFFFF4444[DragonUI]|r " .. msg)
            return
        end

        frame:Hide()
        local dialog = StaticPopup_Show("DRAGONUI_POSITION_PRESET_IMPORT_NAME")
        if dialog then
            dialog.data = data
        end
    end)
    frame:Show()
    frame.editBox:SetFocus()
end

local function ShowGameTooltip(owner, title, line2)
    GameTooltip:SetOwner(owner, "ANCHOR_BOTTOM")
    if GameTooltip.SetFrameStrata then
        GameTooltip:SetFrameStrata("TOOLTIP")
    end
    GameTooltip:SetFrameLevel(9999)
    GameTooltip:AddLine(title, 1, 1, 1)
    if line2 then
        GameTooltip:AddLine(line2, 0.7, 0.7, 0.7)
    end
    GameTooltip:Show()
end

local function CreatePanelEditBox(parent, width)
    local editBox = CreateFrame("EditBox", nil, parent)
    editBox:SetSize(width, 20)
    editBox:SetFontObject(GameFontHighlightSmall)
    editBox:SetAutoFocus(false)
    editBox:SetMaxLetters(40)
    editBox:SetFrameLevel(parent:GetFrameLevel() + 5)
    editBox:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 8,
        edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    editBox:SetBackdropColor(0, 0, 0, 0.6)
    editBox:SetBackdropBorderColor(0.09, 0.52, 0.82, 0.6)
    editBox:SetTextInsets(4, 4, 0, 0)
    return editBox
end

local function SaveFromPanelInput()
    if not presetPanel or not presetPanel.nameInput then
        return
    end

    local name = strtrim(presetPanel.nameInput:GetText() or "")
    name = name:gsub("|", "")
    if name == "" then
        name = PositionPresets:UniqueName(L["Position Preset"])
    end

    if PositionPresets:Save(name) then
        addon:Print("|cFF00FF00[DragonUI]|r " .. L["Position preset saved: "] .. name)
        presetPanel.nameInput:SetText(PositionPresets:UniqueName(L["Position Preset"]))
        presetPanel.nameInput:HighlightText()
        PositionPresets:RefreshPanel()
    end
end

local function ClearPresetRows()
    for _, row in ipairs(presetRows) do
        row:Hide()
        row:SetParent(nil)
    end
    wipe(presetRows)
end

local function GetListContentHeight(nameCount)
    if nameCount == 0 then
        return 18
    end
    return nameCount * ROW_HEIGHT
end

local function SavePanelPosition()
    if not presetPanel or not addon.db or not addon.db.profile then
        return
    end

    local point, _, relativePoint, x, y = presetPanel:GetPoint(1)
    if not point then
        return
    end

    addon.db.profile.widgets = addon.db.profile.widgets or {}
    addon.db.profile.widgets[PANEL_WIDGET_KEY] = {
        anchor = point,
        relativePoint = relativePoint or point,
        posX = math.floor((x or 0) + 0.5),
        posY = math.floor((y or 0) + 0.5),
        custom_position = true,
    }
end

local function ApplyPanelPosition(panel)
    local cfg = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets[PANEL_WIDGET_KEY]
    panel:ClearAllPoints()
    if cfg and cfg.custom_position then
        panel:SetPoint(
            cfg.anchor or "TOPLEFT",
            UIParent,
            cfg.relativePoint or "BOTTOMLEFT",
            cfg.posX or 0,
            cfg.posY or 0
        )
    else
        panel:SetPoint("TOP", UIParent, "CENTER", 0, PANEL_TOP_OFFSET)
    end
end

local function SetPanelHeightExpandDown(panel, newHeight)
    if not panel then
        return
    end

    local left = panel:GetLeft()
    local top = panel:GetTop()
    if left and top then
        panel:ClearAllPoints()
        panel:SetHeight(newHeight)
        panel:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)
    else
        panel:SetHeight(newHeight)
    end
end

function PositionPresets:UpdatePanelHeight()
    if not presetPanel then
        return
    end

    if not menuExpanded then
        SetPanelHeightExpandDown(presetPanel, HEADER_HEIGHT)
        return
    end

    local names = self:GetSortedNames()
    local scrollHeight = math.min(GetListContentHeight(#names), MAX_LIST_HEIGHT)
    local rowGap = 4
    local bodyHeight = SAVE_ROW_HEIGHT + rowGap + scrollHeight + rowGap + FOOTER_HEIGHT

    if presetPanel.bodyFrame then
        presetPanel.bodyFrame:SetHeight(bodyHeight)
    end

    if presetPanel.scrollFrame then
        presetPanel.scrollFrame:SetSize(LIST_WIDTH, scrollHeight)
    end

    if presetPanel.listContent then
        presetPanel.listContent:SetSize(LIST_WIDTH, GetListContentHeight(#names))
    end

    SetPanelHeightExpandDown(presetPanel, HEADER_HEIGHT + 4 + bodyHeight + PANEL_PADDING)
end

function PositionPresets:RefreshPanel()
    if not presetPanel then
        return
    end

    ClearPresetRows()

    if not presetPanel.listContent then
        return
    end

    local names = self:GetSortedNames()
    local content = presetPanel.listContent

    if #names == 0 then
        if not presetPanel.emptyLabel then
            presetPanel.emptyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
            presetPanel.emptyLabel:SetPoint("TOPLEFT", 0, 0)
            presetPanel.emptyLabel:SetWidth(LIST_WIDTH)
            presetPanel.emptyLabel:SetJustifyH("LEFT")
        end
        presetPanel.emptyLabel:SetText(L["No position presets saved yet."])
        presetPanel.emptyLabel:Show()
    else
        if presetPanel.emptyLabel then
            presetPanel.emptyLabel:Hide()
        end

        local btnWidth = LIST_WIDTH - 56

        for index, presetName in ipairs(names) do
            local row = CreateFrame("Frame", nil, content)
            row:SetSize(LIST_WIDTH, ROW_HEIGHT)
            row:SetPoint("TOPLEFT", 0, -((index - 1) * ROW_HEIGHT))

            local loadButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            loadButton:SetSize(btnWidth, ROW_HEIGHT - 2)
            loadButton:SetPoint("LEFT", 0, 0)
            loadButton:SetText(presetName)
            StylePanelButton(loadButton)
            loadButton:SetScript("OnClick", function()
                local dialog = StaticPopup_Show("DRAGONUI_POSITION_PRESET_LOAD", presetName)
                if dialog then
                    dialog.data = presetName
                end
            end)
            loadButton:SetScript("OnEnter", function(self)
                ShowGameTooltip(self, presetName, L["Click to load"])
            end)
            loadButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            local deleteButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            deleteButton:SetSize(24, ROW_HEIGHT - 2)
            deleteButton:SetPoint("LEFT", loadButton, "RIGHT", 4, 0)
            deleteButton:SetText("x")
            StylePanelButton(deleteButton)
            deleteButton:SetScript("OnClick", function()
                local dialog = StaticPopup_Show("DRAGONUI_POSITION_PRESET_DELETE", presetName)
                if dialog then
                    dialog.data = presetName
                end
            end)
            deleteButton:SetScript("OnEnter", function(self)
                ShowGameTooltip(self, L["Delete Preset"], presetName)
            end)
            deleteButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            local exportButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
            exportButton:SetSize(24, ROW_HEIGHT - 2)
            exportButton:SetPoint("LEFT", deleteButton, "RIGHT", 4, 0)
            exportButton:SetText(">")
            StylePanelButton(exportButton)
            exportButton:SetScript("OnClick", function()
                local exportString = PositionPresets:ExportToString(presetName)
                if exportString then
                    ShowExportFrame(presetName, exportString)
                else
                    addon:Print("|cFFFF4444[DragonUI]|r " .. L["Failed to export position preset."])
                end
            end)
            exportButton:SetScript("OnEnter", function(self)
                ShowGameTooltip(self, L["Export Preset"], presetName)
            end)
            exportButton:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)

            presetRows[#presetRows + 1] = row
        end
    end

    self:UpdatePanelHeight()
end

function PositionPresets:CollapseMenu()
    menuExpanded = false
    if not presetPanel then
        return
    end

    presetPanel.bodyFrame:Hide()
    SetPanelHeightExpandDown(presetPanel, HEADER_HEIGHT)
    if presetPanel.toggleButton then
        presetPanel.toggleButton:SetText("|cff888888+|r")
    end
end

function PositionPresets:ExpandMenu()
    menuExpanded = true
    if not presetPanel then
        return
    end

    presetPanel.bodyFrame:Show()
    if presetPanel.toggleButton then
        presetPanel.toggleButton:SetText("|cff888888-|r")
    end
    self:RefreshPanel()
end

function PositionPresets:ToggleMenu()
    if menuExpanded then
        self:CollapseMenu()
    else
        self:ExpandMenu()
    end
end

function PositionPresets:CreatePanel()
    if presetPanel then
        return presetPanel
    end

    local panel = CreateFrame("Frame", "DragonUI_PositionPresetPanel", UIParent)
    panel:SetSize(PANEL_WIDTH, HEADER_HEIGHT)
    ApplyPanelPosition(panel)
    panel:SetFrameStrata(EDITOR_UI_STRATA)
    panel:SetFrameLevel(EDITOR_UI_LEVEL)
    panel:SetClampedToScreen(true)
    panel:EnableMouse(true)
    panel:SetMovable(true)

    local background = CreateFrame("Frame", nil, panel)
    background:SetAllPoints(panel)
    background:SetFrameLevel(panel:GetFrameLevel())
    background:SetBackdrop(BD_PANEL)
    background:SetBackdropColor(0.08, 0.08, 0.10, 0.92)
    background:SetBackdropBorderColor(0.09, 0.52, 0.82, 0.8)
    panel.background = background

    local dragBar = CreateFrame("Frame", nil, panel)
    dragBar:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -3)
    dragBar:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -30, -3)
    dragBar:SetHeight(HEADER_HEIGHT - 6)
    dragBar:SetFrameLevel(panel:GetFrameLevel() + 2)
    dragBar:EnableMouse(true)
    dragBar:RegisterForDrag("LeftButton")
    dragBar:SetScript("OnDragStart", function()
        panel:StartMoving()
    end)
    dragBar:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        SavePanelPosition()
    end)

    local dragTitle = dragBar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    dragTitle:SetPoint("LEFT", dragBar, "LEFT", 8, 0)
    dragTitle:SetTextColor(0.4, 0.8, 1)
    dragTitle:SetText(L["Position Presets"])
    panel.dragTitle = dragTitle

    local toggleButton = CreateFrame("Button", "DragonUI_PositionPresetToggle", panel, "UIPanelButtonTemplate")
    toggleButton:SetSize(24, HEADER_HEIGHT - 6)
    toggleButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -4, -3)
    toggleButton:SetText("|cff888888+|r")
    toggleButton:SetFrameLevel(panel:GetFrameLevel() + 10)
    StylePanelButton(toggleButton)
    toggleButton:SetScript("OnClick", function()
        PositionPresets:ToggleMenu()
    end)
    panel.toggleButton = toggleButton

    dragBar:SetScript("OnEnter", function(self)
        ShowGameTooltip(self, L["Position Presets"], L["Drag to move"])
    end)
    dragBar:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    local bodyFrame = CreateFrame("Frame", nil, panel)
    bodyFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", PANEL_PADDING, -(HEADER_HEIGHT + 4))
    bodyFrame:SetWidth(CONTENT_WIDTH)
    bodyFrame:SetHeight(SAVE_ROW_HEIGHT + MAX_LIST_HEIGHT + FOOTER_HEIGHT + 12)
    bodyFrame:SetFrameLevel(panel:GetFrameLevel() + 4)
    bodyFrame:Hide()
    panel.bodyFrame = bodyFrame

    local saveRow = CreateFrame("Frame", nil, bodyFrame)
    saveRow:SetPoint("TOPLEFT", bodyFrame, "TOPLEFT", 0, 0)
    saveRow:SetSize(CONTENT_WIDTH, SAVE_ROW_HEIGHT)
    saveRow:SetFrameLevel(bodyFrame:GetFrameLevel())

    local saveButtonWidth = 52
    local nameInput = CreatePanelEditBox(saveRow, CONTENT_WIDTH - saveButtonWidth - 4)
    nameInput:SetPoint("LEFT", saveRow, "LEFT", 0, 0)
    nameInput:SetText(PositionPresets:UniqueName(L["Position Preset"]))
    nameInput:SetScript("OnEnterPressed", function(self)
        SaveFromPanelInput()
        self:ClearFocus()
    end)
    nameInput:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    panel.nameInput = nameInput

    local saveButton = CreateFrame("Button", nil, saveRow, "UIPanelButtonTemplate")
    saveButton:SetSize(saveButtonWidth, SAVE_ROW_HEIGHT - 2)
    saveButton:SetPoint("LEFT", nameInput, "RIGHT", 4, 0)
    saveButton:SetText(L["Save"])
    StylePanelButton(saveButton)
    saveButton:SetScript("OnClick", SaveFromPanelInput)
    panel.saveButton = saveButton

    local scrollFrame = CreateFrame("ScrollFrame", "DragonUI_PositionPresetScroll", bodyFrame, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", saveRow, "BOTTOMLEFT", 0, -4)
    scrollFrame:SetSize(LIST_WIDTH, MAX_LIST_HEIGHT)
    scrollFrame:SetFrameLevel(bodyFrame:GetFrameLevel() + 2)
    panel.scrollFrame = scrollFrame

    local listContent = CreateFrame("Frame", nil, scrollFrame)
    listContent:SetSize(LIST_WIDTH, MAX_LIST_HEIGHT)
    scrollFrame:SetScrollChild(listContent)
    panel.listContent = listContent

    local importButton = CreateFrame("Button", nil, bodyFrame, "UIPanelButtonTemplate")
    importButton:SetSize(LIST_WIDTH, ROW_HEIGHT - 2)
    importButton:SetPoint("TOPLEFT", scrollFrame, "BOTTOMLEFT", 0, -4)
    importButton:SetText(L["Import Preset"])
    StylePanelButton(importButton)
    importButton:SetScript("OnClick", ShowImportFrame)
    panel.importButton = importButton

    panel:Hide()
    presetPanel = panel
    return panel
end

function PositionPresets:ShowPanel()
    local panel = self:CreatePanel()
    self:CollapseMenu()
    panel:Show()
end

function PositionPresets:HidePanel()
    if presetPanel then
        self:CollapseMenu()
        presetPanel:Hide()
    end
end

function PositionPresets:IsPanelShown()
    return presetPanel and presetPanel:IsShown()
end
