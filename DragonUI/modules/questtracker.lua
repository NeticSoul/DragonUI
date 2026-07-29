local addon = select(2, ...);
local L = addon.L

-- =============================================================================
-- DRAGONUI QUEST TRACKER MODULE 
-- =============================================================================

local QuestTrackerModule = {
    initialized = false,
    applied = false,
    originalWatchFramePoint = nil,
}
addon.QuestTrackerModule = QuestTrackerModule

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("questtracker", QuestTrackerModule,
        (addon.L and addon.L["Quest Tracker"]) or "Quest Tracker",
        (addon.L and addon.L["Quest tracker positioning and styling"]) or "Quest tracker positioning and styling")
end

QuestTrackerModule.questTrackerFrame = nil

-- =============================================================================
-- MODULE ENABLED CHECK
-- =============================================================================
local function GetModuleConfig()
    return addon:GetModuleConfig("questtracker")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("questtracker")
end

-- =============================================================================
-- CONFIG SYSTEM (DragonUI style using database)
-- =============================================================================
local function GetQuestTrackerConfig()
    if not (addon.db and addon.db.profile and addon.db.profile.questtracker) then
        return -210, -255, "TOPRIGHT", true -- defaults matching database.lua
    end
    local config = addon.db.profile.questtracker
    return config.x or -210, config.y or -255, config.anchor or "TOPRIGHT", config.show_header ~= false
end

-- Returns the configured font size (defaults to WoW's built-in 11pt if unset)
local function GetQuestFontSize()
    if addon.db and addon.db.profile and addon.db.profile.questtracker then
        return addon.db.profile.questtracker.font_size or 12
    end
    return 12
end

-- Lines use profile font_size; WatchFrameTitle is sized separately (12 narrow / 14 wide).
local function ApplyQuestTrackerFonts()
    local targetSize = GetQuestFontSize()
    local lineSets = { WATCHFRAME_QUESTLINES, WATCHFRAME_ACHIEVEMENTLINES }
    for _, lineSet in ipairs(lineSets) do
        if lineSet then
            for _, line in ipairs(lineSet) do
                if line then
                    if line.text and line.text.GetFont then
                        local fp, _, fl = line.text:GetFont()
                        if fp then line.text:SetFont(fp, targetSize, fl) end
                    end
                    if line.dash and line.dash.GetFont then
                        local fp, _, fl = line.dash:GetFont()
                        if fp then line.dash:SetFont(fp, targetSize, fl) end
                    end
                end
            end
        end
    end

    local title = WatchFrameTitle
    if title and title.GetFont then
        local path, _, flags = title:GetFont()
        if path then
            local wide = WatchFrame and (WatchFrame:GetWidth() or 0) > 250
            title:SetFont(path, wide and 14 or 12, flags)
        end
    end
end

-- =============================================================================
-- TIMER FUNCTIONS FOR 3.3.5 COMPATIBILITY
-- =============================================================================
local timerFrames = {}
local function ScheduleTimer(delay, func)
    local timerFrame = CreateFrame("Frame")
    local elapsed = 0
    timerFrame:SetScript("OnUpdate", function(self, delta)
        elapsed = elapsed + delta
        if elapsed >= delay then
            func()
            self:Hide()
            self:SetScript("OnUpdate", nil)
            timerFrames[self] = nil
        end
    end)
    timerFrame:Show()
    timerFrames[timerFrame] = true
end

-- =============================================================================
-- REPLACE BLIZZARD FRAME (WITH DELAY FIX)
-- =============================================================================
local watchFrameAttached = false

-- Height for quest display — must be set explicitly because SetUserPlaced(true)
-- prevents Blizzard's UIParent_ManageFramePositions from managing WatchFrame size.
-- Without this, WatchFrame_Update calculates maxHeight from tiny/stale bounds
-- and only shows 1-2 quests.
local QUESTTRACKER_MAX_HEIGHT = 600

local function ReplaceBlizzardFrame(frame)
    local watchFrame = WatchFrame
    if not watchFrame then return end

    -- First time: do the full alpha-hide dance to avoid visual glitch
    if not watchFrameAttached then
        watchFrame:SetAlpha(0)
        watchFrame:EnableMouse(false)
        watchFrame:SetMovable(true)
        watchFrame:SetUserPlaced(true)
        watchFrame:ClearAllPoints()
        watchFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        watchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)

        -- Reposition WatchFrameLines below header (RetailUI pattern)
        -- This ensures quest lines render below the header background
        if WatchFrameLines and WatchFrameHeader then
            WatchFrameLines:SetPoint("TOPLEFT", WatchFrameHeader, 'BOTTOMLEFT', 0, -15)
        end

        ScheduleTimer(0.1, function()
            -- A bare SetAlpha(1) here stomped the fade set at Initialize(), flashing the tracker on reload.
            if QuestTrackerModule.SyncHoverVisibility then
                QuestTrackerModule:SyncHoverVisibility()
            else
                watchFrame:SetAlpha(1)
            end
        end)
        watchFrameAttached = true
    else
        -- Already attached — just silently reposition without alpha flicker
        watchFrame:SetUserPlaced(true)
        watchFrame:ClearAllPoints()
        watchFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
        watchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)
    end
end

-- =============================================================================
-- QUEST COUNTING FUNCTIONS (FIXED - includes IsQuestWatched check)
-- =============================================================================
local function GetTrackedQuestsCount()
    local count = 0
    local success, numWatches = pcall(GetNumQuestWatches)
    if success and numWatches then
        for i = 1, numWatches do
            local questIndex = GetQuestIndexForWatch(i)
            if questIndex and IsQuestWatched(questIndex) then
                count = count + 1
            end
        end
    end
    return count
end

-- =============================================================================
-- QUEST TRACKER STYLING (NON-INTRUSIVE APPROACH)
-- =============================================================================
-- Re-apply after Collapse/Expand SetTexCoord; skip set_atlas (SetWidth can resize the button).
local function ApplyCollapseExpandButtonArt()
    local btn = WatchFrameCollapseExpandButton
    if not btn then return end

    local collapsed = WatchFrame and WatchFrame.collapsed
    local normalAtlas = collapsed and 'QuestTracker-Expand' or 'QuestTracker-Collapse'
    local pushedAtlas = collapsed and 'QuestTracker-Expand-Pressed' or 'QuestTracker-Collapse-Pressed'

    local function skinTex(tex, atlas)
        if not tex or not addon.functions.atlas_unpack then return end
        local path, _, _, left, right, top, bottom = addon.functions.atlas_unpack(atlas)
        if not path then return end
        tex:SetTexture(path)
        tex:SetTexCoord(left, right, top, bottom)
        tex:SetAllPoints(btn)
    end

    skinTex(btn:GetNormalTexture(), normalAtlas)
    skinTex(btn:GetPushedTexture(), pushedAtlas)
    local disabled = btn:GetDisabledTexture()
    if disabled then
        skinTex(disabled, normalAtlas)
        disabled:SetDesaturated(true)
    end

    local hi = btn:GetHighlightTexture()
    if hi then
        skinTex(hi, 'QuestTracker-Red-Highlight')
        hi:SetBlendMode('ADD')
    end
end

local function ApplyQuestTrackerStyling()
    local watchFrame = WatchFrame
    if not watchFrame or not watchFrame:IsShown() then return end
    if not WatchFrameCollapseExpandButton then return end

    -- Use fixed quest counting
    local trackedQuestsCount = GetTrackedQuestsCount()

    local headerWidth = watchFrame:GetWidth() or 230
    local isWide = headerWidth > 250
    local btnW = isWide and 18 or 13
    local btnH = isWide and 19 or 14
    local btn = WatchFrameCollapseExpandButton
    local headerHeight = headerWidth / 8

    watchFrame.background = watchFrame.background or watchFrame:CreateTexture(nil, 'BACKGROUND')
    local background = watchFrame.background

    local success, err = pcall(background.set_atlas, background, 'QuestTracker-Header', true)
    if not success then
        return
    end

    -- Wide: lift title + collapse on Y; art pinned to WatchFrame so lift does not move it.
    local lift = isWide and 5 or 0
    btn:SetSize(btnW, btnH)
    btn:ClearAllPoints()
    btn:SetPoint('TOPRIGHT', watchFrame, 'TOPRIGHT', -12, -5 + lift - (19 - btnH) / 2)
    if WatchFrameHeader then
        WatchFrameHeader:ClearAllPoints()
        WatchFrameHeader:SetPoint('TOPLEFT', watchFrame, 'TOPLEFT', 0, -6 + lift)
    end
    -- Wide: header title 1px up; collapse button stays put.
    if WatchFrameTitle and WatchFrameHeader then
        WatchFrameTitle:ClearAllPoints()
        WatchFrameTitle:SetPoint('TOPLEFT', WatchFrameHeader, 'TOPLEFT', 0, isWide and 1 or 0)
    end
    background:ClearAllPoints()
    if isWide then
        -- X matches button RIGHT (-12); Y fixed independent of lift.
        background:SetPoint('RIGHT', watchFrame, 'TOPRIGHT', -12, -8)
    else
        background:SetPoint('RIGHT', btn, 'RIGHT', 0, 0)
    end
    background:SetSize(headerWidth, headerHeight)
    background:SetAlpha(0.9)
    ApplyCollapseExpandButtonArt()

    -- Get show_header setting
    local _, _, _, showHeader = GetQuestTrackerConfig()

    -- Hide header when QuestHelper is loaded (its own tracker conflicts visually)
    local questHelperLoaded = IsAddOnLoaded and IsAddOnLoaded("QuestHelper")

    -- Show background only when there are quests, header is enabled, and QuestHelper is not loaded
    if trackedQuestsCount > 0 and showHeader and not questHelperLoaded then
        background:Show()
    else
        background:Hide()
    end
end

-- =============================================================================
-- ENHANCED UPDATE FUNCTION WITH PROTECTION
-- =============================================================================
local updateInProgress = false
local lastUpdateTime = 0

local function ForceUpdateQuestTracker()
    if updateInProgress then return end
    
    local now = GetTime()
    if now - lastUpdateTime < 0.05 then return end -- Faster updates (20/sec max)
    
    updateInProgress = true
    lastUpdateTime = now
    
    -- Ensure WatchFrame has sufficient height BEFORE Blizzard's update runs.
    -- This is critical: WatchFrame_Update calculates maxHeight from GetTop()-GetBottom(),
    -- and without explicit height, the frame shrinks to content → circular limitation.
    if WatchFrame then
        WatchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)
    end

    -- Never call WatchFrame_Update directly from addon code: that taints
    -- WatchFrame globals and can later trigger blocked actions in combat.
    if WatchFrame and WatchFrameLines and WatchFrameHeader then
        WatchFrameLines:SetPoint("TOPLEFT", WatchFrameHeader, 'BOTTOMLEFT', 0, -15)
    end

    ApplyQuestTrackerFonts()
    pcall(ApplyQuestTrackerStyling)
    
    updateInProgress = false
end

-- =============================================================================
-- POSITION UPDATE
-- =============================================================================
local function UpdateQuestTrackerPosition()
    if QuestTrackerModule.questTrackerFrame then
        local x, y, anchor = GetQuestTrackerConfig()
        QuestTrackerModule.questTrackerFrame:ClearAllPoints()
        QuestTrackerModule.questTrackerFrame:SetPoint(anchor, UIParent, anchor, x, y)
    end
end

-- =============================================================================
-- DRAGONUI REFRESH FUNCTION
-- =============================================================================
function addon.RefreshQuestTracker()
    if not IsModuleEnabled() then return end
    
    UpdateQuestTrackerPosition()
    ForceUpdateQuestTracker()
    -- A second update after a short delay stabilises font layout:
    -- the first update applies the new font to all FontStrings so their
    -- GetHeight() values are correct; the second update re-runs the
    -- handler layout pass using those correct heights.
    ScheduleTimer(0.05, ForceUpdateQuestTracker)
end

-- Cached each SyncQuestTrackerHitRect pass; used by watchFrameContentHoverProxy below since
-- IsMouseOver() ignores SetHitRectInsets and would otherwise poll-hover the full padded frame.
local lastContentBottom = nil

-- Stands in for WatchFrame in hoverFrames — real IsMouseOver() ignores SetHitRectInsets, so hover
-- polling would trigger across the whole padded frame instead of just the quest content.
local watchFrameContentHoverProxy = {
    IsVisible = function() return WatchFrame and WatchFrame:IsVisible() end,
    IsMouseOver = function()
        -- nil lastContentBottom = empty tracker; do not fall back to the padded 600px frame.
        if not WatchFrame or not lastContentBottom then return false end
        local top, left, right = WatchFrame:GetTop(), WatchFrame:GetLeft(), WatchFrame:GetRight()
        if not (top and left and right) then return false end
        -- UIParent's scale, not WatchFrame's — GetLeft/Right/Top/Bottom() report in that space.
        local scale = UIParent:GetEffectiveScale()
        local x, y = GetCursorPosition()
        x, y = x / scale, y / scale
        return x >= left and x <= right and y <= top and y >= lastContentBottom
    end,
    HookScript = function(_, ...) return WatchFrame:HookScript(...) end,
    EnableMouse = function(_, ...) return WatchFrame:EnableMouse(...) end,
}

-- =============================================================================
-- INITIALIZATION
-- =============================================================================
function QuestTrackerModule:Initialize()
    if self.initialized then return end
    
    -- Check if module is enabled
    if not IsModuleEnabled() then
        return
    end

    self.questTrackerFrame = CreateFrame('Frame', 'DragonUI_QuestTrackerFrame', UIParent)
    self.questTrackerFrame:SetSize(230, 32)  -- Anchor frame: minimal height, WatchFrame manages its own size
    self.questTrackerFrame:SetFrameLevel(100)
    self.questTrackerFrame:SetFrameStrata('FULLSCREEN')
    self.questTrackerFrame:EnableMouse(false)
    self.questTrackerFrame:SetMovable(false)
    
    -- Add nineslice overlay for editor mode (DragonflightUI style)
    if addon.AddNineslice then
        addon.AddNineslice(self.questTrackerFrame)
        addon.SetNinesliceState(self.questTrackerFrame, false)
        addon.HideNineslice(self.questTrackerFrame)
        -- Legacy editorTexture reference for compatibility
        self.questTrackerFrame.editorTexture = self.questTrackerFrame.NineSlice and self.questTrackerFrame.NineSlice.Center
    end
    
    -- Create text label for editor mode
    do
        local L = addon.L
        local fontString = self.questTrackerFrame:CreateFontString(nil, "OVERLAY", 'GameFontNormalLarge')
        fontString:SetPoint("CENTER", self.questTrackerFrame, "CENTER", 0, 0)
        fontString:SetText(L and L["Quest Tracker"] or "Quest Tracker")
        fontString:Hide()
        self.questTrackerFrame.editorText = fontString
    end

    -- Save original WatchFrame position for restore
    if WatchFrame then
        local point, relativeTo, relativePoint, x, y = WatchFrame:GetPoint()
        self.originalWatchFramePoint = { point, relativeTo, relativePoint, x, y }
    end

    -- Position the frame
    UpdateQuestTrackerPosition()
    
    -- Replace the frame immediately upon initialization
    ReplaceBlizzardFrame(self.questTrackerFrame)

    -- Register with Editor Mode system
    if addon.RegisterEditableFrame then
        addon:RegisterEditableFrame({
            name = "questtracker",
            frame = self.questTrackerFrame,
            blizzardFrame = WatchFrame,
            configPath = nil,  -- Use custom save logic (handled in OnDragStop)
            showTest = function()
                QuestTrackerModule:ShowEditorTest()
            end,
            hideTest = function()
                QuestTrackerModule:HideEditorTest(true)
            end,
            onShow = function()
                -- Clamp quest tracker to screen when in editor mode
                self.questTrackerFrame:SetClampedToScreen(true)
            end,
            onHide = function()
                -- Remove screen clamp when exiting editor mode
                self.questTrackerFrame:SetClampedToScreen(false)
                -- Position is already saved by OnDragStop
                -- Just update WatchFrame position after editor mode
                UpdateQuestTrackerPosition()
                ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)
                ForceUpdateQuestTracker()
            end,
            module = QuestTrackerModule
        })
    end

    self.initialized = true
    self.applied = true

    -- Apply font immediately so WoW's first render already uses our size
    ApplyQuestTrackerFonts()

    if addon.VisibilityFade and WatchFrame then
        -- clickThrough lets the shared engine manage EnableMouse for show_on_hover/show_in_combat/
        -- hide_in_combat generically — WatchFrame isn't secure, so it can react live in combat too.
        addon.VisibilityFade.Register("questtracker", WatchFrame, {
            dbTable = function()
                if not IsModuleEnabled() then return nil end
                return addon.db and addon.db.profile and addon.db.profile.questtracker
            end,
            hoverFrames = { watchFrameContentHoverProxy, WatchFrameHeader, WatchFrameCollapseExpandButton },
            enableMouse = false,
            clickThrough = true,
            mouseSafeInCombat = true,
        })
    end

    self:SyncHoverVisibility()
end

-- These buttons sit on top of WatchFrame, so hovering them steals its OnEnter/OnLeave unless hooked too.
local function SyncQuestLineHoverButtons()
    if not (addon.VisibilityFade and WatchFrame) then return end
    local found = {}
    for i = 1, 40 do
        local link = _G["WatchFrameLinkButton" .. i]
        if link then table.insert(found, link) end
        local item = _G["WatchFrameItem" .. i]
        if item then table.insert(found, item) end
    end
    if #found > 0 then
        addon.VisibilityFade.AddHoverFrames("questtracker", found)
    end
end

-- WatchFrame's height is padded to QUESTTRACKER_MAX_HEIGHT, so shrink the hit rect to the visible content.
local function SyncQuestTrackerHitRect()
    if not WatchFrame then return end
    local top = WatchFrame:GetTop()
    local frameBottom = WatchFrame:GetBottom()
    if not (top and frameBottom) then return end

    -- Hidden header still has GetBottom(); using it left a phantom click strip on the padded frame.
    local function ExcludeEntireFrame()
        WatchFrame:SetHitRectInsets(0, 0, 0, math.max(0, top - frameBottom))
        lastContentBottom = nil
    end

    local contentBottom = nil
    if WatchFrameHeader and WatchFrameHeader:IsShown() then
        contentBottom = WatchFrameHeader:GetBottom()
    end
    local function considerLines(lineSet)
        if not lineSet then return end
        for _, line in pairs(lineSet) do
            if line and line.IsShown and line:IsShown() then
                local b = line:GetBottom()
                if b and (not contentBottom or b < contentBottom) then
                    contentBottom = b
                end
            end
        end
    end
    considerLines(WATCHFRAME_QUESTLINES)
    considerLines(WATCHFRAME_ACHIEVEMENTLINES)
    for i = 1, 40 do
        local item = _G["WatchFrameItem" .. i]
        if item and item:IsShown() then
            local b = item:GetBottom()
            if b and (not contentBottom or b < contentBottom) then
                contentBottom = b
            end
        end
    end

    if not contentBottom then
        ExcludeEntireFrame()
        return
    end

    local bottomInset = math.max(0, (contentBottom - frameBottom) - 4)
    WatchFrame:SetHitRectInsets(0, 0, 0, bottomInset)
    lastContentBottom = contentBottom
end

function QuestTrackerModule:SyncHoverVisibility()
    if not WatchFrame then return end
    -- EnableMouse is now handled by addon.VisibilityFade's clickThrough (covers show_in_combat and
    -- hide_in_combat too, not just show_on_hover like this used to before it was migrated).
    if addon.VisibilityFade then
        addon.VisibilityFade.Update("questtracker")
    end
    SyncQuestTrackerHitRect()
end

-- =============================================================================
-- APPLY/RESTORE SYSTEM
-- =============================================================================
function QuestTrackerModule:ApplySystem()
    if self.applied then return end
    
    if not self.initialized then
        self:Initialize()
        return
    end
    
    if self.questTrackerFrame then
        ReplaceBlizzardFrame(self.questTrackerFrame)
        UpdateQuestTrackerPosition()
        ForceUpdateQuestTracker()
    end

    self.applied = true

    self:SyncHoverVisibility()
end

function QuestTrackerModule:RestoreSystem()
    if not self.applied then return end
    
    -- Restore original WatchFrame position
    if WatchFrame and self.originalWatchFramePoint then
        WatchFrame:ClearAllPoints()
        local p = self.originalWatchFramePoint
        WatchFrame:SetPoint(p[1], p[2] or UIParent, p[3], p[4], p[5])
        WatchFrame:SetAlpha(1)
        WatchFrame:EnableMouse(true)
        WatchFrame:SetUserPlaced(false)
    end

    if addon.VisibilityFade then
        addon.VisibilityFade.Reset("questtracker")
    end


    -- Hide our frame's background
    if WatchFrame and WatchFrame.background then
        WatchFrame.background:Hide()
    end

    if WatchFrameHeader then
        WatchFrameHeader:ClearAllPoints()
        WatchFrameHeader:SetPoint('TOPLEFT', WatchFrame, 'TOPLEFT', 0, -6)
    end
    if WatchFrameTitle and WatchFrameHeader then
        WatchFrameTitle:ClearAllPoints()
        WatchFrameTitle:SetPoint('TOPLEFT', WatchFrameHeader, 'TOPLEFT', 0, 0)
    end
    if WatchFrameCollapseExpandButton then
        WatchFrameCollapseExpandButton:SetSize(16, 16)
        WatchFrameCollapseExpandButton:ClearAllPoints()
        WatchFrameCollapseExpandButton:SetPoint('TOPRIGHT', WatchFrame, 'TOPRIGHT', -12, -5)
    end
    
    self.applied = false
end

-- =============================================================================
-- HOOK SYSTEM WITH PROTECTION (ENHANCED)
-- =============================================================================
local hooksInstalled = false

local function InstallQuestTrackerHooks()
    -- Check that WatchFrame exists and is fully initialized
    if not WatchFrame or hooksInstalled then return end

    -- Hook WatchFrame_Collapse for width adjustment (prevents actual collapse)
    if WatchFrame_Collapse then
        hooksecurefunc('WatchFrame_Collapse', function(self)
            if self then
                self:SetWidth(WATCHFRAME_EXPANDEDWIDTH or 204)
            end
            if IsModuleEnabled() then
                ApplyCollapseExpandButtonArt()
            end
        end)
    end

    if WatchFrame_Expand then
        hooksecurefunc('WatchFrame_Expand', function()
            if IsModuleEnabled() then
                ApplyCollapseExpandButtonArt()
            end
        end)
    end

    -- Hook WatchFrame_Update to keep our visual adjustments without replacing
    -- Blizzard objective layout logic (quests, achievements, timed entries).
    local watchFrameHookActive = false
    if WatchFrame_Update then
        hooksecurefunc('WatchFrame_Update', function()
            if watchFrameHookActive then return end  -- Prevent re-entrancy
            if not IsModuleEnabled() then return end
            if not QuestTrackerModule.initialized then return end

            local watchFrame = WatchFrame
            if not watchFrame then return end

            local lineFrame = WatchFrameLines
            if not lineFrame then return end

            -- Re-assert explicit height (Blizzard may have shrunk it to content)
            watchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)

            -- Re-assert WatchFrameLines position (Blizzard may reset it)
            if WatchFrameHeader then
                WatchFrameLines:SetPoint("TOPLEFT", WatchFrameHeader, 'BOTTOMLEFT', 0, -15)
            end

            watchFrameHookActive = true

            -- Apply font after Blizzard layout pass.
            ApplyQuestTrackerFonts()

            -- Apply background styling after layout.
            pcall(ApplyQuestTrackerStyling)

            SyncQuestLineHoverButtons()
            SyncQuestTrackerHitRect()

            watchFrameHookActive = false
        end)
    end

    -- Additional hooks to ensure quests are displayed correctly
    hooksecurefunc('AddQuestWatch', function(questIndex)
        ScheduleTimer(0.05, ForceUpdateQuestTracker)
    end)

    hooksecurefunc('RemoveQuestWatch', function(questIndex)
        ScheduleTimer(0.05, ForceUpdateQuestTracker)
    end)

    -- Keep tracker consistent when tracked achievements are toggled.
    if AddTrackedAchievement then
        hooksecurefunc('AddTrackedAchievement', function()
            ScheduleTimer(0.05, ForceUpdateQuestTracker)
        end)
    end

    if RemoveTrackedAchievement then
        hooksecurefunc('RemoveTrackedAchievement', function()
            ScheduleTimer(0.05, ForceUpdateQuestTracker)
        end)
    end
    
    -- Add hook for abandoning quests
    if AbandonQuest then
        hooksecurefunc('AbandonQuest', function()
            ScheduleTimer(0.05, ForceUpdateQuestTracker)
        end)
    end
    
    -- Add hook for quest log updates
    if QuestLog_Update then
        hooksecurefunc('QuestLog_Update', function()
            ScheduleTimer(0.05, ForceUpdateQuestTracker)
        end)
    end
    
    -- Hook SetCVar for wide/narrow quest tracker toggle (Interface > Display option)
    hooksecurefunc("SetCVar", function(name)
        if name == "watchFrameWidth" then
            ScheduleTimer(0.2, function()
                if not IsModuleEnabled() then return end
                ForceUpdateQuestTracker()
                -- Reattach WatchFrame to our anchor (Blizzard repositions it on width change)
                if QuestTrackerModule.questTrackerFrame then
                    UpdateQuestTrackerPosition()
                    ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)
                end
            end)
        end
    end)

    -- Hook UIParent_ManageFramePositions to prevent Blizzard from overriding our position
    -- WatchFrame is NOT a secure frame, so we can reposition it freely during combat
    if UIParent_ManageFramePositions then
        hooksecurefunc("UIParent_ManageFramePositions", function()
            if not IsModuleEnabled() then return end
            if not QuestTrackerModule.initialized then return end
            if QuestTrackerModule.questTrackerFrame then
                ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)
            end
            -- Re-assert height in case Blizzard touched it
            if WatchFrame then
                WatchFrame:SetHeight(QUESTTRACKER_MAX_HEIGHT)
            end
        end)
    end

    -- GetItemCooldown returns nil mid-swap; a post-hook can't stop the original erroring, so wrap it.
    if WatchFrameItem_UpdateCooldown then
        local original = WatchFrameItem_UpdateCooldown
        WatchFrameItem_UpdateCooldown = function(self)
            local ok = pcall(original, self)
            if not ok and self and self.Cooldown then
                self.Cooldown:Hide()
            end
        end
    end

    hooksInstalled = true
end

-- =============================================================================
-- EDITOR MODE FUNCTIONS
-- =============================================================================
function QuestTrackerModule:ShowEditorTest()
    if self.questTrackerFrame then
        self.questTrackerFrame:SetMovable(true)
        self.questTrackerFrame:EnableMouse(true)
        self.questTrackerFrame:RegisterForDrag("LeftButton")
        
        -- Update frame size to match WatchFrame dimensions
        if WatchFrame then
            local watchWidth = WatchFrame:GetWidth() or 230
            local watchHeight = WatchFrame:GetHeight() or 200
            self.questTrackerFrame:SetSize(watchWidth, watchHeight)
        end
        
        -- Show nineslice overlay
        if self.questTrackerFrame.NineSlice and addon.ShowNineslice then
            addon.SetNinesliceState(self.questTrackerFrame, false)
            addon.ShowNineslice(self.questTrackerFrame)
        end
        
        -- Show text
        if self.questTrackerFrame.editorText then
            self.questTrackerFrame.editorText:Show()
        end

        -- Click to select in editor panel
        self.questTrackerFrame:SetScript("OnMouseDown", function(frame, button)
            if button == "LeftButton" and addon.SelectEditorFrame then
                addon.SelectEditorFrame(frame)
            end
        end)

        self.questTrackerFrame:SetScript("OnDragStart", function(frame)
            frame:StartMoving()
            -- Ensure selected
            if addon.selectedEditorFrame ~= frame and addon.SelectEditorFrame then
                addon.SelectEditorFrame(frame)
            end
            -- Clear green tint while dragging
            if addon.ClearSelectionTint then
                addon.ClearSelectionTint(frame)
            end
        end)

        self.questTrackerFrame:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            frame:SetScript("OnUpdate", nil)
            -- Re-apply green tint after drop
            if addon.ApplySelectionTint then
                addon.ApplySelectionTint(frame)
            end
            -- Keep quest tracker persistence in TOPRIGHT space so reload position is
            -- stable even when editor-test frame size differs from runtime frame size.
            local screenWidth = UIParent:GetRight()
            local screenHeight = UIParent:GetTop()
            local right = frame:GetRight()
            local top = frame:GetTop()
            if right and top and screenWidth and screenHeight then
                local point = "TOPRIGHT"
                local x = right - screenWidth
                local y = -(screenHeight - top)
                x = math.floor(x + 0.5)
                y = math.floor(y + 0.5)
                -- Re-anchor the frame properly
                frame:ClearAllPoints()
                frame:SetPoint(point, UIParent, point, x, y)
                frame:SetUserPlaced(false)
                -- Save position to DragonUI database
                if addon.db and addon.db.profile then
                    if not addon.db.profile.questtracker then
                        addon.db.profile.questtracker = {}
                    end
                    addon.db.profile.questtracker.anchor = point
                    addon.db.profile.questtracker.x = x
                    addon.db.profile.questtracker.y = y
                end
            end
        end)
    end
end

function QuestTrackerModule:HideEditorTest(savePosition)
    if self.questTrackerFrame then
        self.questTrackerFrame:SetMovable(false)
        self.questTrackerFrame:EnableMouse(false)
        self.questTrackerFrame:SetScript("OnDragStart", nil)
        self.questTrackerFrame:SetScript("OnDragStop", nil)
        self.questTrackerFrame:SetScript("OnMouseDown", nil)
        
        -- Hide nineslice overlay
        if self.questTrackerFrame.NineSlice and addon.HideNineslice then
            addon.HideNineslice(self.questTrackerFrame)
        end
        if self.questTrackerFrame.editorText then
            self.questTrackerFrame.editorText:Hide()
        end

        if savePosition then
            UpdateQuestTrackerPosition()
        end
    end
end

-- =============================================================================
-- EVENT SYSTEM (WITH DELAYED HOOK INSTALLATION)
-- =============================================================================
local function OnPlayerEnteringWorld()
    -- Check if module is enabled
    if not IsModuleEnabled() then return end

    -- Apply font immediately (before hooks are installed) to avoid visible size jump
    ApplyQuestTrackerFonts()
    ScheduleTimer(0.1, ApplyQuestTrackerFonts)
    ScheduleTimer(0.3, ApplyQuestTrackerFonts)
    ScheduleTimer(0.6, ApplyQuestTrackerFonts)

    -- Reapply position on every world entry (login, reload, zone change)
    -- This counters Blizzard's UIParent_ManageFramePositions overriding us
    ScheduleTimer(0.3, function()
        if QuestTrackerModule.initialized and QuestTrackerModule.questTrackerFrame then
            UpdateQuestTrackerPosition()
            ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)
        end
    end)
    
    -- Set up hooks after world load completion with delay (critical fix)
    if not hooksInstalled then
        ScheduleTimer(1.0, function()
            InstallQuestTrackerHooks()
            ForceUpdateQuestTracker()
        end)
    end
end

-- Quest log update handler with change detection
local lastQuestUpdate = 0
local previousQuestCount = 0

local function OnQuestLogUpdate()
    -- Check if module is enabled
    if not IsModuleEnabled() then return end
    
    local now = GetTime()
    if now - lastQuestUpdate < 0.05 then return end
    lastQuestUpdate = now
    
    -- Only update when quest count actually changes
    local currentQuestCount = GetTrackedQuestsCount()
    if currentQuestCount ~= previousQuestCount then
        previousQuestCount = currentQuestCount
        ScheduleTimer(0.05, ForceUpdateQuestTracker)
    end
end

-- Initialize module
addon.package:RegisterEvents(function()
    if IsModuleEnabled() then
        QuestTrackerModule:Initialize()
    end
end, 'PLAYER_LOGIN')

-- Register PLAYER_ENTERING_WORLD 
addon.package:RegisterEvents(OnPlayerEnteringWorld, 'PLAYER_ENTERING_WORLD')

-- Register quest log update event
addon.package:RegisterEvents(OnQuestLogUpdate, 'QUEST_LOG_UPDATE')

