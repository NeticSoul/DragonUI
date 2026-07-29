local addon = select(2, ...)
local L = addon.L

-- =============================================================================
-- DRAGONUI LOOT ROLL MODULE
-- Moves GroupLootContainer (the parent of all roll frames) to a custom position.
-- Uses the same approach as DragonflightUI: reposition the container, not the
-- individual GroupLootFrame1-4.  This keeps Blizzard's internal frame stacking
-- intact and survives /reload without breaking roll functionality.
-- =============================================================================

local LootRollModule = {
    initialized = false,
    applied = false,
}
addon.LootRollModule = LootRollModule

-- Loot Roll is not registered as a toggleable module — it always runs.
-- Position is managed via Editor Mode only.

-- =============================================================================
-- DEFAULT POSITION
-- =============================================================================
local DEFAULTS = {
    anchor = "BOTTOM",
    x = 0,
    y = 200,
}

-- =============================================================================
-- CONFIG
-- =============================================================================
local function GetLootRollConfig()
    if not (addon.db and addon.db.profile and addon.db.profile.lootroll) then
        return DEFAULTS.x, DEFAULTS.y, DEFAULTS.anchor
    end
    local cfg = addon.db.profile.lootroll
    return cfg.x or DEFAULTS.x, cfg.y or DEFAULTS.y, cfg.anchor or DEFAULTS.anchor
end

-- =============================================================================
-- POSITION HELPERS
-- =============================================================================

--- Move the invisible anchor frame to the saved (or default) position.
local function UpdateAnchorPosition()
    local anchor = LootRollModule.anchorFrame
    if not anchor then return end
    local x, y, point = GetLootRollConfig()
    anchor:ClearAllPoints()
    anchor:SetPoint(point, UIParent, point, x, y)
end

--- Attach GroupLootContainer to the bottom of our anchor frame.
--- Blizzard keeps managing frames *inside* the container; we only move
--- the container itself.
--- Falls back to repositioning individual GroupLootFrame1-4 if the
--- container global doesn't exist on this client.
local attachingContainer = false  -- re-entrancy guard
local fallbackHooksInstalled = false

local function AttachContainer()
    local anchor = LootRollModule.anchorFrame
    if not anchor then return end

    if GroupLootContainer then
        -- Preferred path: move the whole container
        GroupLootContainer.ignoreFramePositionManager = true

        -- Guard against our own SetPoint hook re-entering
        attachingContainer = true
        GroupLootContainer:ClearAllPoints()
        GroupLootContainer:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
        attachingContainer = false
    else
        -- Fallback: reposition individual frames (older clients without container)
        attachingContainer = true
        for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
            local frame = _G["GroupLootFrame" .. i]
            if frame then
                frame:ClearAllPoints()
                if i == 1 then
                    frame:SetPoint("BOTTOM", anchor, "BOTTOM", 0, 0)
                else
                    local prev = _G["GroupLootFrame" .. (i - 1)]
                    frame:SetPoint("BOTTOM", prev, "TOP", 0, 4)
                end
            end
        end
        attachingContainer = false
    end
end

-- =============================================================================
-- HOOKS  (installed once, survive reload because we re-install on PLAYER_LOGIN)
-- =============================================================================
local hookInstalled = false
local function InstallHooks()
    if hookInstalled then return end

    if GroupLootContainer then
        -- Hook SetPoint on the container so if anything (Blizzard or another
        -- addon) tries to reposition it, we immediately correct.
        hooksecurefunc(GroupLootContainer, "SetPoint", function()
            if not LootRollModule.applied then return end
            if attachingContainer then return end   -- our own call
            AttachContainer()
        end)
    end

    -- Also hook GroupLootContainer_Update if it exists
    if GroupLootContainer_Update then
        hooksecurefunc("GroupLootContainer_Update", function()
            if not LootRollModule.applied then return end
            AttachContainer()
        end)
    end

    -- Fallback: hook individual frame openers for clients without the container
    if not GroupLootContainer and GroupLootFrame_OpenNewFrame then
        hooksecurefunc("GroupLootFrame_OpenNewFrame", function()
            if not LootRollModule.applied then return end
            AttachContainer()
        end)
    end

    -- Fallback: also self-correct each frame directly, so a reposition while
    -- a roll is already open (not just on new-frame-open) gets caught too.
    if not GroupLootContainer and not fallbackHooksInstalled then
        fallbackHooksInstalled = true
        for i = 1, NUM_GROUP_LOOT_FRAMES or 4 do
            local frame = _G["GroupLootFrame" .. i]
            if frame then
                hooksecurefunc(frame, "SetPoint", function()
                    if not LootRollModule.applied then return end
                    if attachingContainer then return end
                    AttachContainer()
                end)
            end
        end
    end

    hookInstalled = true
end

-- =============================================================================
-- INITIALIZATION
-- =============================================================================
function LootRollModule:Initialize()
    if self.initialized then return end

    -- Create invisible anchor frame the user drags in editor mode
    local anchor = CreateFrame("Frame", "DragonUI_LootRollAnchor", UIParent)
    local refFrame = GroupLootContainer or _G["GroupLootFrame1"]
    local w = refFrame and refFrame:GetWidth() or 240
    local h = refFrame and refFrame:GetHeight() or 28
    anchor:SetSize(w, h)
    anchor:EnableMouse(false)
    anchor:SetMovable(false)

    -- Add nineslice overlay for editor mode
    if addon.AddNineslice then
        addon.AddNineslice(anchor)
        addon.SetNinesliceState(anchor, false)
        addon.HideNineslice(anchor)
    end

    -- Create text label for editor mode
    local L = addon.L
    local fontString = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    fontString:SetPoint("CENTER")
    fontString:SetText(L and L["Loot Roll"] or "Loot Roll")
    fontString:Hide()
    anchor.editorText = fontString

    self.anchorFrame = anchor

    -- Position anchor & attach container
    UpdateAnchorPosition()
    InstallHooks()
    AttachContainer()

    -- Register with Editor Mode
    if addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "lootroll",
            frame = anchor,
            configPath = nil, -- Custom save logic in OnDragStop
            showTest = function()
                LootRollModule:ShowEditorTest()
            end,
            hideTest = function()
                LootRollModule:HideEditorTest()
            end,
            onHide = function()
                UpdateAnchorPosition()
                AttachContainer()
            end,
            module = LootRollModule
        })
    end

    self.initialized = true
    self.applied = true
end

-- =============================================================================
-- APPLY / RESTORE
-- =============================================================================
function LootRollModule:ApplySystem()
    if not self.initialized then
        self:Initialize()
        return
    end

    UpdateAnchorPosition()
    AttachContainer()
    self.applied = true
end

-- Public refresh helper used by position presets and profile operations.
function addon.RefreshLootRoll()
    if not LootRollModule.initialized then
        LootRollModule:Initialize()
        return
    end

    UpdateAnchorPosition()
    AttachContainer()
end

function LootRollModule:RestoreSystem()
    if not self.applied then return end
    -- Give the container back to Blizzard's position manager
    if GroupLootContainer then
        GroupLootContainer.ignoreFramePositionManager = nil
    end
    self.applied = false
    -- Note: we don't restore individual frame positions because Blizzard
    -- will recalculate them on the next GroupLootContainer_Update / roll event.
end

-- =============================================================================
-- EDITOR MODE
-- =============================================================================
function LootRollModule:ShowEditorTest()
    local frame = self.anchorFrame
    if not frame then return end

    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")

    -- Show nineslice
    if frame.NineSlice and addon.ShowNineslice then
        addon.SetNinesliceState(frame, false)
        addon.ShowNineslice(frame)
    end

    if frame.editorText then
        frame.editorText:Show()
    end

    -- Click to select in editor panel
    frame:SetScript("OnMouseDown", function(f, button)
        if button == "LeftButton" and addon.SelectEditorFrame then
            addon.SelectEditorFrame(f)
        end
    end)

    frame:SetScript("OnDragStart", function(f)
        f:StartMoving()
        -- Ensure selected
        if addon.selectedEditorFrame ~= f and addon.SelectEditorFrame then
            addon.SelectEditorFrame(f)
        end
        -- Clear green tint while dragging (show default drag nineslice)
        if addon.ClearSelectionTint then
            addon.ClearSelectionTint(f)
        end
    end)

    frame:SetScript("OnDragStop", function(f)
        f:StopMovingOrSizing()
        f:SetScript("OnUpdate", nil)
        -- Re-apply green tint after drop (frame stays selected)
        if addon.ApplySelectionTint then
            addon.ApplySelectionTint(f)
        end

        -- Calculate position relative to screen quadrant
        local screenWidth = UIParent:GetRight()
        local screenHeight = UIParent:GetTop()
        local screenCenterX = UIParent:GetCenter()
        local cx, cy = f:GetCenter()
        if cx and cy then
            local LEFT = screenWidth / 3
            local RIGHT = screenWidth * 2 / 3
            local TOP = screenHeight / 2
            local point, x, y

            if cy >= TOP then
                point = "TOP"
                y = -(screenHeight - f:GetTop())
            else
                point = "BOTTOM"
                y = f:GetBottom()
            end

            if cx >= RIGHT then
                point = point .. "RIGHT"
                x = f:GetRight() - screenWidth
            elseif cx <= LEFT then
                point = point .. "LEFT"
                x = f:GetLeft()
            else
                x = cx - screenCenterX
            end

            x = math.floor(x + 0.5)
            y = math.floor(y + 0.5)

            f:ClearAllPoints()
            f:SetPoint(point, UIParent, point, x, y)
            f:SetUserPlaced(false)

            -- Save to DB
            if addon.db and addon.db.profile then
                if not addon.db.profile.lootroll then
                    addon.db.profile.lootroll = {}
                end
                addon.db.profile.lootroll.anchor = point
                addon.db.profile.lootroll.x = x
                addon.db.profile.lootroll.y = y
            end

            -- Re-attach container to new position
            AttachContainer()
        end
    end)
end

function LootRollModule:HideEditorTest()
    local frame = self.anchorFrame
    if not frame then return end

    frame:SetMovable(false)
    frame:EnableMouse(false)
    frame:SetScript("OnDragStart", nil)
    frame:SetScript("OnDragStop", nil)
    frame:SetScript("OnMouseDown", nil)

    if frame.NineSlice and addon.HideNineslice then
        addon.HideNineslice(frame)
    end
    if frame.editorText then
        frame.editorText:Hide()
    end
end

-- =============================================================================
-- EVENTS
-- =============================================================================
addon.package:RegisterEvents(function()
    LootRollModule:Initialize()
end, "PLAYER_LOGIN")

-- Re-attach after zone changes, reloads, etc. (same as DragonflightUI pattern)
addon.package:RegisterEvents(function()
    if LootRollModule.applied then
        AttachContainer()
    end
end, "PLAYER_ENTERING_WORLD")

