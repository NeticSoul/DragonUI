local addon = select(2, ...);

-- =============================================================================
-- DRAGONUI QUEST TRACKER MODULE (identical to RetailUI)
-- =============================================================================

local QuestTrackerModule = {}
addon.QuestTrackerModule = QuestTrackerModule

QuestTrackerModule.questTrackerFrame = nil

-- =============================================================================
-- REPLACE BLIZZARD FRAME (identical to RetailUI)
-- =============================================================================
local function ReplaceBlizzardFrame(frame)
    local watchFrame = WatchFrame
    if not watchFrame then return end

    watchFrame:SetMovable(true)
    watchFrame:SetUserPlaced(true)
    watchFrame:ClearAllPoints()
    watchFrame:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    --  EXACTO COMO RETAILUI (sin verificaciones)
    WatchFrameLines:SetPoint("TOPLEFT", WatchFrameHeader, 'BOTTOMLEFT', 0, -15)
end
local function GetQuestTrackerConfig()
    if not (addon.db and addon.db.profile and addon.db.profile.questtracker) then
        return -100, -37, "TOPRIGHT", true --  defaults con show_header = true
    end
    local config = addon.db.profile.questtracker
    return config.x or -100, config.y or -37, config.anchor or "TOPRIGHT", config.show_header ~= false
end
-- =============================================================================
-- QUEST TRACKER STYLING (identical to RetailUI)
-- =============================================================================
local function WatchFrame_Collapse(self)
    self:SetWidth(WATCHFRAME_EXPANDEDWIDTH)
end

local function WatchFrame_Update(self)
    local pixelsUsed = 0
    local totalOffset = WATCHFRAME_INITIAL_OFFSET
    local lineFrame = WatchFrameLines
    local maxHeight = (WatchFrame:GetTop() - WatchFrame:GetBottom())

    local maxFrameWidth = WATCHFRAME_MAXLINEWIDTH
    local maxLineWidth
    local numObjectives
    local totalObjectives = 0

    --  EXACTO COMO RETAILUI
    for i = 1, #WATCHFRAME_OBJECTIVEHANDLERS do
        pixelsUsed, maxLineWidth, numObjectives = WATCHFRAME_OBJECTIVEHANDLERS[i](lineFrame, totalOffset, maxHeight, maxFrameWidth)
        totalObjectives = totalObjectives + numObjectives
    end

    --  EXACTO COMO RETAILUI (usando .background, no .dragonUIBackground)
    local watchFrame = WatchFrame
    watchFrame.background = watchFrame.background or watchFrame:CreateTexture(nil, 'BACKGROUND')
    local background = watchFrame.background
    background:SetPoint('RIGHT', WatchFrameCollapseExpandButton, 'RIGHT', 0, 0)

    --  FUNCIÓN ATLAS IGUAL QUE RETAILUI
    SetAtlasTexture(background, 'QuestTracker-Header')
    background:SetSize(watchFrame:GetWidth(), 36)

    --  LÓGICA MODIFICADA: Verificar configuración show_header EN TIEMPO REAL
    local _, _, _, showHeader = GetQuestTrackerConfig()
    if totalObjectives > 0 and showHeader then
        background:Show()
        background:SetAlpha(1)
    else
        background:Hide()
    end
end

-- =============================================================================
-- CONFIG SYSTEM (DragonUI style using database)
-- =============================================================================
local function GetQuestTrackerConfig()
    if not (addon.db and addon.db.profile and addon.db.profile.questtracker) then
        return -100, -37, "TOPRIGHT", false --  defaults con show_header = true
    end
    local config = addon.db.profile.questtracker
    return config.x or -100, config.y or -37, config.anchor or "TOPRIGHT", config.show_header ~= false
end

local function UpdateQuestTrackerPosition()
    if InCombatLockdown() then return end

    if QuestTrackerModule.questTrackerFrame then
        local x, y, anchor = GetQuestTrackerConfig()
        QuestTrackerModule.questTrackerFrame:ClearAllPoints()
        QuestTrackerModule.questTrackerFrame:SetPoint(anchor, UIParent, anchor, x, y)
    end

    if _G["WatchFrameLines"] then
        _G["WatchFrameLines"]:ClearAllPoints()
        _G["WatchFrameLines"]:SetPoint("TOPLEFT", _G["WatchFrameHeader"], 'BOTTOMLEFT', 0, -15)
    end
end

-- =============================================================================
-- DRAGONUI REFRESH FUNCTION
-- =============================================================================
function addon.RefreshQuestTracker()
    if InCombatLockdown() then return end
    UpdateQuestTrackerPosition()

    --  FORZAR ACTUALIZACIÓN DEL HEADER EN TIEMPO REAL
    if WatchFrame_Update and WatchFrame then
        WatchFrame_Update(WatchFrame)
    end
end

-- =============================================================================
-- INITIALIZATION (adapted from RetailUI OnEnable)
-- =============================================================================
function QuestTrackerModule:Initialize()
    --  IGUAL QUE RETAILUI (CreateUIFrame equivalente)
    self.questTrackerFrame = CreateFrame('Frame', 'DragonUI_QuestTrackerFrame', UIParent)
    self.questTrackerFrame:SetSize(230, 500)

    -- Position the frame
    UpdateQuestTrackerPosition()

    -- Replace Blizzard frame (igual que RetailUI)
    ReplaceBlizzardFrame(self.questTrackerFrame)

    --  HOOKS EXACTOS COMO RETAILUI (SecureHook equivalent)
    hooksecurefunc('WatchFrame_Collapse', WatchFrame_Collapse)
    hooksecurefunc('WatchFrame_Update', WatchFrame_Update)


end

-- =============================================================================
-- EDITOR MODE FUNCTIONS (equivalent to RetailUI ShowEditorTest/HideEditorTest)
-- =============================================================================
function QuestTrackerModule:ShowEditorTest()
    if self.questTrackerFrame then
        self.questTrackerFrame:SetMovable(true)
        self.questTrackerFrame:EnableMouse(true)
        self.questTrackerFrame:RegisterForDrag("LeftButton")

        self.questTrackerFrame:SetScript("OnDragStart", function(frame)
            frame:StartMoving()
        end)

        self.questTrackerFrame:SetScript("OnDragStop", function(frame)
            frame:StopMovingOrSizing()
            -- Save position to DragonUI database
            local point, _, relativePoint, x, y = frame:GetPoint()
            if addon.db and addon.db.profile then
                -- Initialize questtracker config if not exists
                if not addon.db.profile.questtracker then
                    addon.db.profile.questtracker = {}
                end
                addon.db.profile.questtracker.anchor = point
                addon.db.profile.questtracker.x = x
                addon.db.profile.questtracker.y = y
            end
        end)


    end
end

function QuestTrackerModule:HideEditorTest(savePosition)
    if self.questTrackerFrame then
        self.questTrackerFrame:SetMovable(false)
        self.questTrackerFrame:EnableMouse(false)
        self.questTrackerFrame:SetScript("OnDragStart", nil)
        self.questTrackerModule:SetScript("OnDragStop", nil)

        if savePosition then
            UpdateQuestTrackerPosition()

        end
    end
end

-- =============================================================================
-- EVENT SYSTEM (adapted from RetailUI PLAYER_ENTERING_WORLD)
-- =============================================================================
local function OnPlayerEnteringWorld()
    if QuestTrackerModule.questTrackerFrame then
        ReplaceBlizzardFrame(QuestTrackerModule.questTrackerFrame)
    end
end

-- Initialize module
addon.package:RegisterEvents(function()
    QuestTrackerModule:Initialize()
end, 'PLAYER_LOGIN')

-- Register PLAYER_ENTERING_WORLD (like RetailUI)
addon.package:RegisterEvents(OnPlayerEnteringWorld, 'PLAYER_ENTERING_WORLD')

-- Profile change handler
if addon.core and addon.core.RegisterMessage then
    addon.core.RegisterMessage(addon, "DRAGONUI_PROFILE_CHANGED", function()
        addon.RefreshQuestTracker()
    end)
end
