-- ============================================================================
-- DragonUI Options - XP & Rep Bars Tab
-- ============================================================================
local addon = DragonUI
if not addon then return end

local L = addon.L
local LO = addon.LO
local Panel = addon.OptionsPanel
local C = addon.PanelControls

-- Shared callback: refresh the entire XP/Rep bar system
local function RefreshBars()
    if addon.RefreshXpRepBars then addon.RefreshXpRepBars() end
end

local function BuildXpRepTab(scroll)
    local isDFUI = (C:GetDBValue("xprepbar.style") or "dragonflightui") == "dragonflightui"
    local isRetail = not isDFUI

    -- ====================================================================
    -- STYLE SELECTOR
    -- ====================================================================
    local styleSection = C:AddSection(scroll, LO["Bar Style"])

    C:AddDropdown(styleSection, {
        label = LO["XP / Rep Bar Style"],
        desc = LO["DragonflightUI: fully custom bars with rested XP background.\nRetailUI: atlas-based reskin of Blizzard bars.\n\nChanging style requires a UI reload."],
        dbPath = "xprepbar.style",
        values = {
            dragonflightui = LO["DragonflightUI"],
            retailui = LO["RetailUI"],
        },
        width = 200,
        callback = function()
            -- Sync style.xpbar for legacy compat
            local newStyle = C:GetDBValue("xprepbar.style")
            C:SetDBValue("style.xpbar", newStyle)
            -- Prompt reload — style is saved to DB but NOT applied live.
            -- On reload, the new style initializes cleanly from scratch.
            StaticPopupDialogs["DRAGONUI_RELOAD_XPSTYLE"] = {
                text = LO["XP bar style changed to "] .. (newStyle == "retailui" and LO["RetailUI"] or LO["DragonflightUI"]) .. ".\n" .. LO["A UI reload is required to apply this change."],
                button1 = LO["Reload Now"],
                button2 = LO["Cancel"],
                OnAccept = function() ReloadUI() end,
                OnCancel = function()
                    -- Revert the DB value if user cancels
                    local oldStyle = (newStyle == "retailui") and "dragonflightui" or "retailui"
                    C:SetDBValue("xprepbar.style", oldStyle)
                    C:SetDBValue("style.xpbar", oldStyle)
                    Panel:SelectTab("xprepbars")
                end,
                timeout = 0,
                whileDead = true,
                hideOnEscape = false,
                preferredIndex = 3,
            }
            StaticPopup_Show("DRAGONUI_RELOAD_XPSTYLE")
        end,
    })

    -- ====================================================================
    -- BAR DIMENSIONS & SCALE
    -- ====================================================================
    local sizeSection = C:AddSection(scroll, LO["Size & Scale"])

    C:AddSlider(sizeSection, {
        label = LO["Bar Width"],
        desc = LO["Width of the XP and Reputation bars (in pixels)."],
        dbPath = "xprepbar.bar_width",
        min = 200, max = 1500, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(sizeSection, {
        label = LO["Bar Height"],
        desc = LO["Height of the XP and Reputation bars (in pixels)."],
        dbPath = isDFUI and "xprepbar.bar_height_dfui" or "xprepbar.bar_height_retailui",
        min = 6, max = 30, step = 1,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(sizeSection, {
        label = LO["Experience Bar Scale"],
        desc = LO["Scale of the experience bar."],
        dbPath = "xprepbar.expbar_scale",
        min = 0.5, max = 1.5, step = 0.05,
        width = 200,
        callback = RefreshBars,
    })

    C:AddSlider(sizeSection, {
        label = LO["Reputation Bar Scale"],
        desc = LO["Scale of the reputation bar."],
        dbPath = "xprepbar.repbar_scale",
        min = 0.5, max = 1.5, step = 0.05,
        width = 200,
        callback = RefreshBars,
    })

    -- ====================================================================
    -- RESTED XP INDICATORS
    -- ====================================================================
    local restedSection = C:AddSection(scroll, LO["Rested XP"])

    C:AddToggle(restedSection, {
        label = LO["Show Rested XP Background"],
        desc = LO["Display a translucent bar showing the total available rested XP range.\n(DragonflightUI style only)"],
        dbPath = "xprepbar.show_rested_bar",
        disabled = isRetail,
        callback = RefreshBars,
    })

    C:AddToggle(restedSection, {
        label = LO["Show Exhaustion Tick"],
        desc = LO["Show the exhaustion tick indicator on the XP bar, marking where rested XP ends."],
        dbPath = "style.exhaustion_tick",
        callback = function()
            if addon.UpdateExhaustionTick then addon.UpdateExhaustionTick() end
        end,
    })

    -- ====================================================================
    -- TEXT DISPLAY
    -- ====================================================================
    local textSection = C:AddSection(scroll, LO["Text Display"])

    C:AddToggle(textSection, {
        label = LO["Always Show Text"],
        desc = LO["Always display XP/Rep text instead of only on hover."],
        dbPath = "xprepbar.always_show_text",
        callback = RefreshBars,
    })

    C:AddToggle(textSection, {
        label = LO["Show XP Percentage"],
        desc = LO["Display XP percentage alongside the value text."],
        dbPath = "xprepbar.show_xp_percent",
        callback = RefreshBars,
    })

    -- ====================================================================
    -- VISIBILITY
    -- ====================================================================
    local visSection = C:AddSection(scroll, LO["Visibility"])
    C:AddVisibilityFadeToggles(visSection, {
        dbPrefix = "xprepbar",
        hoverDesc = LO["Fade the XP and Reputation bars until you hover over them."],
        combatDesc = LO["Fade the XP and Reputation bars until you enter combat."],
        hideInCombat = true,
        hideInCombatDesc = LO["Hide the XP and Reputation bars while in combat."],
        callback = RefreshBars,
    })
end

-- Register the tab (order 5 = after Additional Bars)
Panel:RegisterTab("xprepbars", LO["XP & Rep Bars"], BuildXpRepTab, 5)
