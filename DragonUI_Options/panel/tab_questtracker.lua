--[[
================================================================================
DragonUI Options Panel - Quest Tracker Tab
================================================================================
Quest tracker position and behavior.
================================================================================
]]

local addon = DragonUI
if not addon then return end

local LO = addon.LO
local C = addon.PanelControls
local Panel = addon.OptionsPanel

-- ============================================================================
-- QUEST TRACKER TAB BUILDER
-- ============================================================================

local function RefreshQT()
    if addon.RefreshQuestTracker then addon.RefreshQuestTracker() end
end

local function BuildQuesttrackerTab(scroll)
    local section = C:AddSection(scroll, LO["Quest Tracker"])

    C:AddDescription(section, LO["Position and display settings for the objective tracker."])

    C:AddToggle(section, {
        label = LO["Show Header Background"],
        desc = LO["Show/hide the decorative header background texture."],
        getFunc = function()
            return C:GetDBValue("questtracker.show_header") ~= false
        end,
        setFunc = function(val)
            C:SetDBValue("questtracker.show_header", val)
            RefreshQT()
        end,
    })

    C:AddSlider(section, {
        label = LO["Font Size"],
        desc = LO["Font size for quest tracker text"],
        dbPath = "questtracker.font_size",
        min = 8, max = 18, step = 1,
        width = 200,
        callback = RefreshQT,
    })

    C:AddHeading(section, LO["Visibility"])
    C:AddVisibilityFadeToggles(section, {
        dbPrefix = "questtracker",
        hoverDesc = LO["Fade the quest tracker until you hover over it."],
        combatDesc = LO["Fade the quest tracker until you enter combat."],
        hideInCombat = true,
        hideInCombatDesc = LO["Hide the quest tracker while in combat."],
        callback = function()
            if addon.QuestTrackerModule and addon.QuestTrackerModule.SyncHoverVisibility then
                addon.QuestTrackerModule:SyncHoverVisibility()
            end
        end,
    })
end

-- Register the tab
Panel:RegisterTab("questtracker", LO["Quest Tracker"], BuildQuesttrackerTab, 10)
