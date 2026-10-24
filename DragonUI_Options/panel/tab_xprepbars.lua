-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
-- DragonUI Options - XP & Rep Bars Tab
-- ============================================================================
local addon = DragonUI
if not addon then return end

local LO = addon.LO
local Panel = addon.OptionsPanel
local C = addon.PanelControls

-- Shared callback: refresh the entire XP/Rep bar system
local function RefreshBars()
    if addon.RefreshXpRepBars then addon.RefreshXpRepBars() end
end

-- ============================================================================
-- EXPERIENCE RATE (server-kept, see DragonUI/modules/xprate.lua)
-- ============================================================================

local XR = addon.XpRate

-- The rate widgets on screen, and what they were built for; nil while another tab shows.
local rateShown

local function RateStatusText()
    local st = XR and XR.State()
    if not st then
        return LO["This realm doesn't keep a personal XP rate, or hasn't answered yet."]
    elseif st.off then
        return LO["XP gain is off: this character doesn't level."]
    elseif XR.IsRamping() then
        return format(LO["Your rate is %s. It grows with your level until level %d, so the first levels don't fly by: %s right now."],
            XR.Format(st.rate), st.rampLevel, XR.Format(XR.Effective()))
    end
    return format(LO["Your rate is %s."], XR.Format(st.rate))
end

local function BuildRateSection(scroll)
    local st = XR and XR.State()
    local section = C:AddSection(scroll, LO["Experience Rate"])

    local status = C:AddDescription(section, RateStatusText())

    local slider = C:AddSlider(section, {
        label = LO["XP Rate"],
        desc = LO["How fast this character levels, from the realm's personal XP rate. The realm keeps it per character. You can also right-click the XP bar."],
        min = st and math.max(0.5, st.min) or 0.5,
        max = st and st.max or 5,
        step = 0.5,
        width = 200,
        getFunc = function() return st and st.rate or 1 end,
        setFunc = function(value) XR.Set(value) end,
        disabled = not st or st.off,
    })

    C:AddToggle(section, {
        label = LO["Gain experience"],
        desc = LO["Turn off to stop this character from leveling."],
        getFunc = function() return st and not st.off end,
        setFunc = function(value) XR.SetGain(value) end,
        disabled = not st,
    })

    C:AddButton(section, {
        label = LO["Use Realm Default"],
        desc = LO["Go back to the rate the realm gives every character."],
        disabled = not st or st.off,
        callback = function() XR.UseDefault() end,
    })

    if not Panel.indexing then
        -- Search results and tab switches release these widgets for reuse elsewhere.
        status:SetCallback("OnRelease", function() rateShown = nil end)
        rateShown = {
            status = status, slider = slider,
            available = st ~= nil, off = st and st.off, max = st and st.max,
        }
    end
end

if XR then
    XR.OnChange(function()
        if not rateShown or not Panel:IsOpen() or Panel.currentTab ~= "xprepbars" then
            rateShown = nil
            return
        end
        local st = XR.State()
        if (st ~= nil) ~= rateShown.available or (st and (st.off ~= rateShown.off or st.max ~= rateShown.max)) then
            -- What can be used changed: rebuild the tab (it keeps the scroll position).
            Panel:SelectTab("xprepbars")
            return
        end
        rateShown.status:SetText(RateStatusText())
        if st and math.abs((rateShown.slider:GetValue() or 0) - st.rate) > 0.001 then
            rateShown.slider:SetValue(st.rate)
        end
    end)
end

local function BuildXpRepTab(scroll)
    local isDFUI = (C:GetDBValue("xprepbar.style") or "dragonflightui") == "dragonflightui"
    local isRetail = not isDFUI

    BuildRateSection(scroll)

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
    C:AddToggle(visSection, {
        label = LO["Hide Experience Bar"],
        desc = LO["Hide the XP bar while you level. The reputation bar moves into its place, as at max level."],
        dbPath = "xprepbar.hide_xp",
        callback = function()
            if addon.RelayoutXpRepBars then addon.RelayoutXpRepBars() end
        end,
    })
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
