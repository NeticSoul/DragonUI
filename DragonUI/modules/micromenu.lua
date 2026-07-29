--[[
    DragonUI MicroMenu Module
    Refactored version maintaining all functionality with better organization
    Now with module enable/disable system

    -- MODULAR VERSION FOR VANILLA & ASCENSION --
]]
local addon = select(2, ...);
local config = addon.config;
local L = addon.L

-- ============================================================================
-- SERVER DETECTION & MODULE STATE
-- ============================================================================

-- Detect if we are on an Ascension server by checking for one of its custom buttons.
-- This is the most reliable method.
local isAscensionServer = (_G.PathToAscensionMicroButton ~= nil)

local MicromenuModule = {
    initialized = false,
    applied = false,
    originalStates = {}, -- Store original states for restoration
    registeredEvents = {}, -- Track registered events
    hooks = {}, -- Track hooked functions
    stateDrivers = {}, -- Track state drivers
    frames = {}, -- Track created frames
    originalHandlers = {}, -- Store original button handlers
    originalSetPoints = {}, -- Store original SetPoint functions
    originalCVars = {}, -- Store original CVar values
    eventFrames = {} -- Track event handler frames
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("micromenu", MicromenuModule,
        (addon.L and addon.L["Micro Menu"]) or "Micro Menu",
        (addon.L and addon.L["Micro menu and bags system styling and positioning"]) or "Micro menu and bags system styling and positioning")
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("micromenu")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("micromenu")
end

local function GetLFGTooltipPosition()
    local pos = addon.db and addon.db.profile and addon.db.profile.widgets and addon.db.profile.widgets.lfgframe
        and addon.db.profile.widgets.lfgframe.tooltip_position
    if pos == "TOP" or pos == "BOTTOM" or pos == "LEFT" or pos == "RIGHT" then
        return pos
    end
    return "TOP"
end

local function GetLFDStatusAnchorSpec(position)
    if position == "BOTTOM" then
        return "TOP", "BOTTOM", 0, -30
    elseif position == "LEFT" then
        return "RIGHT", "LEFT", -24, 0
    elseif position == "RIGHT" then
        return "LEFT", "RIGHT", 24, 0
    end

    -- Default/current behavior.
    return "BOTTOM", "TOP", 0, 30
end

-- ============================================================================
-- SECTION 1: LOCALS AND CONSTANTS
-- ============================================================================

local pairs = pairs;
local gsub = string.gsub;
local UIParent = UIParent;
local hooksecurefunc = hooksecurefunc;
local _G = _G;

-- Performance constants
local PERFORMANCEBAR_LOW_LATENCY = 200;
local PERFORMANCEBAR_MEDIUM_LATENCY = 300;

-- Frame references
local MainMenuBarBackpackButton = _G.MainMenuBarBackpackButton;
local HelpMicroButton = _G.HelpMicroButton;
local KeyRingButton = _G.KeyRingButton;

-- Button collections (dynamically set based on server)
local MICRO_BUTTONS

if isAscensionServer then
    MICRO_BUTTONS = {
        _G.CharacterMicroButton,
        _G.SpellbookMicroButton,
        _G.TalentMicroButton,
        _G.AchievementMicroButton,
        _G.QuestLogMicroButton,
        _G.SocialsMicroButton,
        _G.LFDMicroButton,
        _G.PathToAscensionMicroButton,
        _G.ChallengesMicroButton,
        _G.MainMenuMicroButton,
        _G.HelpMicroButton
    }
else
    MICRO_BUTTONS = {
        _G.CharacterMicroButton,
        _G.SpellbookMicroButton,
        _G.TalentMicroButton,
        _G.AchievementMicroButton,
        _G.QuestLogMicroButton,
        _G.SocialsMicroButton,
        _G.LFDMicroButton,
        _G.CollectionsMicroButton,
        _G.PVPMicroButton,
        _G.MainMenuMicroButton,
        _G.HelpMicroButton
    }
end


local bagslots = {_G.CharacterBag0Slot, _G.CharacterBag1Slot, _G.CharacterBag2Slot, _G.CharacterBag3Slot};

-- State tracking
local originalBlizzardHandlers = {}
local bags_initialized = false
local MainMenuMicroButtonMixin = {};

-- ============================================================================
-- SECTION 2: ATLAS COORDINATES
-- ============================================================================

local MicromenuAtlas = {
    ["UI-HUD-MicroMenu-Achievements-Disabled"] = {0.000976562, 0.0634766, 0.00195312, 0.162109},
    ["UI-HUD-MicroMenu-Achievements-Down"] = {0.000976562, 0.0634766, 0.166016, 0.326172},
    ["UI-HUD-MicroMenu-Achievements-Mouseover"] = {0.000976562, 0.0634766, 0.330078, 0.490234},
    ["UI-HUD-MicroMenu-Achievements-Up"] = {0.000976562, 0.0634766, 0.494141, 0.654297},

    ["UI-HUD-MicroMenu-GameMenu-Disabled"] = {0.129883, 0.192383, 0.330078, 0.490234},
    ["UI-HUD-MicroMenu-GameMenu-Down"] = {0.129883, 0.192383, 0.494141, 0.654297},
    ["UI-HUD-MicroMenu-GameMenu-Mouseover"] = {0.129883, 0.192383, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-GameMenu-Up"] = {0.129883, 0.192383, 0.822266, 0.982422},

    ["UI-HUD-MicroMenu-Groupfinder-Disabled"] = {0.194336, 0.256836, 0.00195312, 0.162109},
    ["UI-HUD-MicroMenu-Groupfinder-Down"] = {0.194336, 0.256836, 0.166016, 0.326172},
    ["UI-HUD-MicroMenu-Groupfinder-Mouseover"] = {0.194336, 0.256836, 0.330078, 0.490234},
    ["UI-HUD-MicroMenu-Groupfinder-Up"] = {0.194336, 0.256836, 0.494141, 0.654297},

    ["UI-HUD-MicroMenu-GuildCommunities-Disabled"] = {0.194336, 0.256836, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-GuildCommunities-Down"] = {0.194336, 0.256836, 0.822266, 0.982422},
    ["UI-HUD-MicroMenu-GuildCommunities-Mouseover"] = {0.258789, 0.321289, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-GuildCommunities-Up"] = {0.258789, 0.321289, 0.822266, 0.982422},

    ["UI-HUD-MicroMenu-Questlog-Disabled"] = {0.323242, 0.385742, 0.494141, 0.654297},
    ["UI-HUD-MicroMenu-Questlog-Down"] = {0.323242, 0.385742, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-Questlog-Mouseover"] = {0.323242, 0.385742, 0.822266, 0.982422},
    ["UI-HUD-MicroMenu-Questlog-Up"] = {0.387695, 0.450195, 0.00195312, 0.162109},

    ["UI-HUD-MicroMenu-SpecTalents-Disabled"] = {0.387695, 0.450195, 0.822266, 0.982422},
    ["UI-HUD-MicroMenu-SpecTalents-Down"] = {0.452148, 0.514648, 0.00195312, 0.162109},
    ["UI-HUD-MicroMenu-SpecTalents-Mouseover"] = {0.452148, 0.514648, 0.166016, 0.326172},
    ["UI-HUD-MicroMenu-SpecTalents-Up"] = {0.452148, 0.514648, 0.330078, 0.490234},

    ["UI-HUD-MicroMenu-SpellbookAbilities-Disabled"] = {0.452148, 0.514648, 0.494141, 0.654297},
    ["UI-HUD-MicroMenu-SpellbookAbilities-Down"] = {0.452148, 0.514648, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-SpellbookAbilities-Mouseover"] = {0.452148, 0.514648, 0.822266, 0.982422},
    ["UI-HUD-MicroMenu-SpellbookAbilities-Up"] = {0.516602, 0.579102, 0.00195312, 0.162109},

    ["UI-HUD-MicroMenu-Shop-Disabled"] = {0.387695, 0.450195, 0.166016, 0.326172},
    ["UI-HUD-MicroMenu-Shop-Down"] = {0.387695, 0.450195, 0.494141, 0.654297},
    ["UI-HUD-MicroMenu-Shop-Mouseover"] = {0.387695, 0.450195, 0.330078, 0.490234},
    ["UI-HUD-MicroMenu-Shop-Up"] = {0.387695, 0.450195, 0.658203, 0.818359}
}

-- Add server-specific atlas data
if isAscensionServer then
    MicromenuAtlas["UI-HUD-MicroMenu-Challenges-Disabled"] = {0.000976562, 0.0634766, 0.658203, 0.818359}
    MicromenuAtlas["UI-HUD-MicroMenu-Challenges-Down"] = {0.000976562, 0.0634766, 0.822266, 0.982422}
    MicromenuAtlas["UI-HUD-MicroMenu-Challenges-Mouseover"] = {0.0654297, 0.12793, 0.00195312, 0.162109}
    MicromenuAtlas["UI-HUD-MicroMenu-Challenges-Up"] = {0.0654297, 0.12793, 0.166016, 0.326172}
    MicromenuAtlas["UI-HUD-MicroMenu-PathToAscension-Disabled"] = {0.0654297, 0.12793, 0.658203, 0.818359}
    MicromenuAtlas["UI-HUD-MicroMenu-PathToAscension-Down"] = {0.0654297, 0.12793, 0.822266, 0.982422}
    MicromenuAtlas["UI-HUD-MicroMenu-PathToAscension-Mouseover"] = {0.129883, 0.192383, 0.00195312, 0.162109}
    MicromenuAtlas["UI-HUD-MicroMenu-PathToAscension-Up"] = {0.129883, 0.192383, 0.166016, 0.326172}
else
    MicromenuAtlas["UI-HUD-MicroMenu-Collections-Disabled"] = {0.0654297, 0.12793, 0.658203, 0.818359}
    MicromenuAtlas["UI-HUD-MicroMenu-Collections-Down"] = {0.0654297, 0.12793, 0.822266, 0.982422}
    MicromenuAtlas["UI-HUD-MicroMenu-Collections-Mouseover"] = {0.129883, 0.192383, 0.00195312, 0.162109}
    MicromenuAtlas["UI-HUD-MicroMenu-Collections-Up"] = {0.129883, 0.192383, 0.166016, 0.326172}
end


-- ============================================================================
-- SECTION 3: UTILITY FUNCTIONS (ALL ORIGINAL CODE PRESERVED)
-- ============================================================================

-- Database persistence helpers
local function GetBagCollapseState()
    if addon.db and addon.db.profile and addon.db.profile.micromenu then
        return addon.db.profile.micromenu.bags_collapsed
    end
    return false
end

local function SetBagCollapseState(collapsed)
    if addon.db and addon.db.profile and addon.db.profile.micromenu then
        addon.db.profile.micromenu.bags_collapsed = collapsed
    end
end

local function ShouldForceCollapsedSecondaryInvisible()
    local actionbars = addon.db and addon.db.profile and addon.db.profile.actionbars
    if not actionbars then
        return false
    end

    local visibilityEnabled = actionbars.bag_show_on_hover or actionbars.bag_show_in_combat
    if not visibilityEnabled then
        return false
    end

    local hiddenAlpha = actionbars.bag_visibility_hidden_alpha
    if hiddenAlpha == nil then
        hiddenAlpha = actionbars.visibility_hidden_alpha
    end

    return (tonumber(hiddenAlpha) or 0) > 0
end

-- Bag icon refresh helper.
-- In 3.3.5a, item textures can be temporarily unavailable right after reload;
-- avoid clearing/hiding valid icon data on transient nil returns.
local function RefreshBagSlotIcons()
    local collapsed = GetBagCollapseState()
    local forceHideCollapsed = collapsed and ShouldForceCollapsedSecondaryInvisible()
    for _, bagButton in pairs(bagslots) do
        if bagButton then
            local icon = _G[bagButton:GetName() .. 'IconTexture']
            if icon then
                local inventorySlot = bagButton:GetID()
                local bagLink = GetInventoryItemLink("player", inventorySlot)
                local itemTexture = GetInventoryItemTexture("player", inventorySlot)

                if bagLink then
                    if itemTexture then
                        icon:SetTexture(itemTexture)
                    end

                    icon:Show()
                    icon:SetAlpha(forceHideCollapsed and 0 or 1)
                    pcall(function()
                        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                    end)
                else
                    icon:SetTexture("Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
                    icon:Show()
                    icon:SetAlpha(0)
                end
            end
        end
    end
end

local function ScheduleBagSlotIconRefreshes()
    RefreshBagSlotIcons()

    if addon.core and addon.core.ScheduleTimer then
        addon.core:ScheduleTimer(function()
            if IsModuleEnabled() then
                RefreshBagSlotIcons()
            end
        end, 0.2)

        addon.core:ScheduleTimer(function()
            if IsModuleEnabled() then
                RefreshBagSlotIcons()
            end
        end, 1.0)
    end
end

-- Adjusts icon alpha for all bag slots to reflect empty/filled state.
-- Blizzard's default handler already updates IconTexture on BAG_UPDATE, so
-- only the alpha fade needs to be applied here.
local PAPERDOLL_BAG_PLACEHOLDER = "interface\\paperdoll\\ui-paperdoll-slot-bag"
local function UpdateBagSlotAlpha()
    local collapsed = GetBagCollapseState()
    local forceHideCollapsed = collapsed and ShouldForceCollapsedSecondaryInvisible()
    for i = 1, #bagslots do
        local bagButton = bagslots[i]
        if bagButton then
            local normalTexture = bagButton:GetNormalTexture()
            if normalTexture then
                normalTexture:SetAlpha(0)
                normalTexture:Hide()
            end

            local icon = _G[bagButton:GetName() .. 'IconTexture']
            if icon then
                local inventorySlot = bagButton:GetID()
                local bagLink = inventorySlot and GetInventoryItemLink("player", inventorySlot) or nil
                local tex = icon:GetTexture()
                local texPath = tex and tostring(tex):lower() or nil
                -- Primary source of truth: equipped bag link.
                -- Texture path is a fallback signal for placeholder visuals.
                local isEmpty = (not bagLink)
                if not isEmpty and texPath and texPath:find(PAPERDOLL_BAG_PLACEHOLDER, 1, true) then
                    isEmpty = true
                end

                if not isEmpty then
                    icon:SetAlpha(forceHideCollapsed and 0 or 1)
                else
                    icon:SetAlpha(0)
                end
            end
        end
    end
end

local collapsedSecondaryFadeDriver

local function StopCollapsedSecondaryFade()
    if collapsedSecondaryFadeDriver then
        collapsedSecondaryFadeDriver:SetScript("OnUpdate", nil)
    end
end

local function ApplyCollapsedSecondaryAlpha(alpha)
    alpha = tonumber(alpha) or 0
    if alpha < 0 then
        alpha = 0
    elseif alpha > 1 then
        alpha = 1
    end

    for i = 1, #bagslots do
        local bags = bagslots[i]
        if bags then
            bags:SetAlpha(alpha)

            if bags.customBorder then
                bags.customBorder:SetAlpha(alpha)
            end
            if bags.background then
                bags.background:SetAlpha(alpha)
            end

            local icon = _G[bags:GetName() .. 'IconTexture']
            if icon then
                local inventorySlot = bags:GetID()
                local bagLink = inventorySlot and GetInventoryItemLink("player", inventorySlot) or nil
                icon:SetAlpha(bagLink and alpha or 0)
            end
        end
    end
end

function addon.RefreshCollapsedSecondaryBagsVisibility(shouldShow)
    if not IsModuleEnabled() then
        return
    end

    local actionbars = addon.db and addon.db.profile and addon.db.profile.actionbars
    if not actionbars or not GetBagCollapseState() then
        StopCollapsedSecondaryFade()
        return
    end

    local visibilityEnabled = actionbars.bag_show_on_hover or actionbars.bag_show_in_combat
    local hiddenAlpha = actionbars.bag_visibility_hidden_alpha
    if hiddenAlpha == nil then
        hiddenAlpha = actionbars.visibility_hidden_alpha
    end
    hiddenAlpha = tonumber(hiddenAlpha) or 0

    if (not visibilityEnabled) or hiddenAlpha > 0 then
        StopCollapsedSecondaryFade()
        return
    end

    if not shouldShow then
        StopCollapsedSecondaryFade()
        ApplyCollapsedSecondaryAlpha(0)
        return
    end

    local startAlpha = 0
    if bagslots[1] and bagslots[1].GetAlpha then
        startAlpha = bagslots[1]:GetAlpha() or 0
    end
    if startAlpha >= 0.99 then
        StopCollapsedSecondaryFade()
        ApplyCollapsedSecondaryAlpha(1)
        return
    end

    if not collapsedSecondaryFadeDriver then
        collapsedSecondaryFadeDriver = CreateFrame("Frame")
    end

    local elapsed = 0
    local duration = 2
    collapsedSecondaryFadeDriver:SetScript("OnUpdate", function(_, delta)
        elapsed = elapsed + delta
        local progress = elapsed / duration

        if progress >= 1 then
            ApplyCollapsedSecondaryAlpha(1)
            StopCollapsedSecondaryFade()
            return
        end

        local alpha = startAlpha + ((1 - startAlpha) * progress)
        ApplyCollapsedSecondaryAlpha(alpha)
    end)
end

-- Atlas helpers
local function GetAtlasKey(buttonName)
    local buttonMap
    if isAscensionServer then
        buttonMap = {
            character = nil, -- Uses portrait
            spellbook = "UI-HUD-MicroMenu-SpellbookAbilities",
            talent = "UI-HUD-MicroMenu-SpecTalents",
            achievement = "UI-HUD-MicroMenu-Achievements",
            questlog = "UI-HUD-MicroMenu-Questlog",
            socials = "UI-HUD-MicroMenu-GuildCommunities",
            lfd = "UI-HUD-MicroMenu-Groupfinder",
            pathtoascension = "UI-HUD-MicroMenu-PathToAscension",
            challenges = "UI-HUD-MicroMenu-Challenges",
            mainmenu = "UI-HUD-MicroMenu-Shop",
            help = "UI-HUD-MicroMenu-GameMenu"
        }
    else
        buttonMap = {
            character = nil,
            spellbook = "UI-HUD-MicroMenu-SpellbookAbilities",
            talent = "UI-HUD-MicroMenu-SpecTalents",
            achievement = "UI-HUD-MicroMenu-Achievements",
            questlog = "UI-HUD-MicroMenu-Questlog",
            socials = "UI-HUD-MicroMenu-GuildCommunities",
            lfd = "UI-HUD-MicroMenu-Groupfinder",
            collections = "UI-HUD-MicroMenu-Collections",
            pvp = nil,
            mainmenu = "UI-HUD-MicroMenu-Shop",
            help = "UI-HUD-MicroMenu-GameMenu"
        }
    end
    return buttonMap[buttonName]
end

local function GetColoredTextureCoords(buttonName, textureType)
    local atlasKey = GetAtlasKey(buttonName)
    if not atlasKey then
        return nil
    end

    local coordsKey = atlasKey .. "-" .. textureType
    local coords = MicromenuAtlas[coordsKey]
    if coords and type(coords) == "table" and #coords >= 4 then
        return coords
    end
    return nil
end

-- Handler management
local function CaptureOriginalHandlers(button)
    local buttonName = button:GetName()
    if not originalBlizzardHandlers[buttonName] then
        originalBlizzardHandlers[buttonName] = {
            OnEnter = button:GetScript('OnEnter'),
            OnLeave = button:GetScript('OnLeave')
        }
    end
end

local function RestoreOriginalHandlers(button)
    local buttonName = button:GetName()
    local handlers = originalBlizzardHandlers[buttonName]
    if handlers then
        if handlers.OnEnter then
            button:SetScript('OnEnter', handlers.OnEnter)
        end
        if handlers.OnLeave then
            button:SetScript('OnLeave', handlers.OnLeave)
        end
    end
end

-- Loot animation helper
local function EnsureLootAnimationToMainBag()
    -- Simple approach: when bags are hidden, WoW should naturally redirect loot to main bag
end

-- Additional utility helpers are defined below (frame cleanup,
-- button setup, and style/state synchronization).
local function UpdateCharacterPortraitVisibility()
    -- Global hooks may still fire after module disable; bail out unless
    -- micromenu is currently applied to preserve vanilla Character button visuals.
    if not MicromenuModule.applied or not IsModuleEnabled() then
        return
    end

    if MicroButtonPortrait then
        if addon and addon.db and addon.db.profile and addon.db.profile.micromenu and
            addon.db.profile.micromenu.grayscale_icons then
            MicroButtonPortrait:Hide()
            MicroButtonPortrait:SetAlpha(0)
        else
            MicroButtonPortrait:Show()
            -- Keep portrait valid after late Blizzard refreshes.
            SetPortraitTexture(MicroButtonPortrait, "player")
            -- Don't set alpha here — the SetPushed/SetNormal hooks and
            -- HandleDragonUIState manage it to avoid race conditions.
        end
    end

    -- Kill Blizzard's native button textures every time UpdateMicroButtons
    -- runs. Blizzard restores them internally; we must re-clear each pass.
    -- Only in colored mode — grayscale uses native textures with atlas.
    local charBtn = _G.CharacterMicroButton
    local useGrayscaleForClear = addon and addon.db and addon.db.profile and addon.db.profile.micromenu and addon.db.profile.micromenu.grayscale_icons
    if charBtn and not useGrayscaleForClear then
        local nt = charBtn:GetNormalTexture()
        if nt then nt:SetTexture(nil) end
        local pt = charBtn:GetPushedTexture()
        if pt then pt:SetTexture(nil) end
        local ht = charBtn:GetHighlightTexture()
        if ht then ht:SetTexture(nil) end
    end

    -- Refresh character highlight so it stays in sync.
    -- Character button background can be hidden by late startup passes.
    local useGrayscale = addon and addon.db and addon.db.profile and addon.db.profile.micromenu and addon.db.profile.micromenu.grayscale_icons
    if charBtn and not useGrayscale and charBtn.DragonUICharHighlight then
        SetPortraitTexture(charBtn.DragonUICharHighlight, "player")
        -- Read current portrait TexCoord instead of hardcoding normal coords.
        -- Blizzard shifts the crop for pushed/normal state; we must match it.
        charBtn.DragonUICharHighlight:SetTexCoord(MicroButtonPortrait:GetTexCoord())
        charBtn.DragonUICharHighlight:SetBlendMode('ADD')
        charBtn.DragonUICharHighlight:SetAlpha(0.5)
        charBtn.DragonUICharHighlight:SetAllPoints(MicroButtonPortrait)
    end
    if charBtn and charBtn.DragonUIBackground then
        local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'

        -- Rehydrate texture data in case a late UI pass stripped it.
        charBtn.DragonUIBackground:SetTexture(microTexture)
        charBtn.DragonUIBackground:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
        if charBtn.DragonUIBackgroundPushed then
            charBtn.DragonUIBackgroundPushed:SetTexture(microTexture)
            charBtn.DragonUIBackgroundPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
        end

        if useGrayscale then
            charBtn.DragonUIBackground:Hide()
            if charBtn.DragonUIBackgroundPushed then
                charBtn.DragonUIBackgroundPushed:Hide()
            end
        else
            if charBtn.dragonUIState and charBtn.dragonUIState.pushed and charBtn.DragonUIBackgroundPushed then
                charBtn.DragonUIBackground:Hide()
                charBtn.DragonUIBackgroundPushed:Show()
            else
                charBtn.DragonUIBackground:Show()
                if charBtn.DragonUIBackgroundPushed then
                    charBtn.DragonUIBackgroundPushed:Hide()
                end
            end
        end
    elseif charBtn and not (addon and addon.db and addon.db.profile and addon.db.profile.micromenu and addon.db.profile.micromenu.grayscale_icons) then
        -- Late safety net: if background was removed, recreate it for colored mode.
        local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
        local dx, dy = -1, 1
        local offX, offY = charBtn:GetPushedTextOffset()
        local sizeX, sizeY = charBtn:GetSize()

        local bg = charBtn:CreateTexture(nil, 'BACKGROUND')
        bg:SetTexture(microTexture)
        bg:SetSize(sizeX, sizeY + 1)
        bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
        bg:SetPoint('CENTER', dx, dy)
        charBtn.DragonUIBackground = bg

        local bgPushed = charBtn:CreateTexture(nil, 'BACKGROUND')
        bgPushed:SetTexture(microTexture)
        bgPushed:SetSize(sizeX, sizeY + 1)
        bgPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
        bgPushed:SetPoint('CENTER', dx + offX, dy + offY)
        bgPushed:Hide()
        charBtn.DragonUIBackgroundPushed = bgPushed

        charBtn.DragonUIBackground:Show()
    end
end
-- ============================================================================
-- APPLY/RESTORE SYSTEM
-- ============================================================================

local function StoreOriginalMicroButtonStates()
    -- Store original positions and parents for all micro buttons
    for _, button in pairs(MICRO_BUTTONS) do
        if button then -- Check if button exists (e.g. PVPMicroButton might not)
            local buttonName = button:GetName()
            if not MicromenuModule.originalStates[buttonName] then
                MicromenuModule.originalStates[buttonName] = {
                    parent = button:GetParent(),
                    points = {},
                    size = {button:GetSize()},
                    scripts = {
                        OnEnter = button:GetScript('OnEnter'),
                        OnLeave = button:GetScript('OnLeave'),
                        OnClick = button:GetScript('OnClick'),
                        OnUpdate = button:GetScript('OnUpdate')
                    },
                    textures = {
                        normal = button:GetNormalTexture() and button:GetNormalTexture():GetTexture(),
                        pushed = button:GetPushedTexture() and button:GetPushedTexture():GetTexture(),
                        highlight = button:GetHighlightTexture() and button:GetHighlightTexture():GetTexture(),
                        disabled = button:GetDisabledTexture() and button:GetDisabledTexture():GetTexture()
                    },
                    SetPoint = button.SetPoint
                }
                -- Store all anchor points
                for i = 1, button:GetNumPoints() do
                    local point, relativeTo, relativePoint, x, y = button:GetPoint(i)
                    table.insert(MicromenuModule.originalStates[buttonName].points, {point, relativeTo, relativePoint, x, y})
                end
            end
        end
    end

    -- Store bag button states
    MicromenuModule.originalStates.MainMenuBarBackpackButton = {
        parent = MainMenuBarBackpackButton:GetParent(),
        points = {},
        size = {MainMenuBarBackpackButton:GetSize()},
        SetPoint = MainMenuBarBackpackButton.SetPoint
    }
    for i = 1, MainMenuBarBackpackButton:GetNumPoints() do
        local point, relativeTo, relativePoint, x, y = MainMenuBarBackpackButton:GetPoint(i)
        table.insert(MicromenuModule.originalStates.MainMenuBarBackpackButton.points,
            {point, relativeTo, relativePoint, x, y})
    end

    -- Store bag slots states
    for idx, bagSlot in pairs(bagslots) do
        local slotName = bagSlot:GetName()
        MicromenuModule.originalStates[slotName] = {
            parent = bagSlot:GetParent(),
            points = {},
            size = {bagSlot:GetSize()}
        }
        for i = 1, bagSlot:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = bagSlot:GetPoint(i)
            table.insert(MicromenuModule.originalStates[slotName].points, {point, relativeTo, relativePoint, x, y})
        end
    end

    -- Store KeyRingButton state
    if KeyRingButton then
        MicromenuModule.originalStates.KeyRingButton = {
            parent = KeyRingButton:GetParent(),
            points = {},
            size = {KeyRingButton:GetSize()}
        }
        for i = 1, KeyRingButton:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = KeyRingButton:GetPoint(i)
            table.insert(MicromenuModule.originalStates.KeyRingButton.points, {point, relativeTo, relativePoint, x, y})
        end
    end

    -- Store LFG frame states
    if MiniMapLFGFrame then
        MicromenuModule.originalStates.MiniMapLFGFrame = {
            points = {},
            scale = MiniMapLFGFrame:GetScale()
        }
        for i = 1, MiniMapLFGFrame:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = MiniMapLFGFrame:GetPoint(i)
            table.insert(MicromenuModule.originalStates.MiniMapLFGFrame.points, {point, relativeTo, relativePoint, x, y})
        end
    end

    -- Store LFDSearchStatus state
    if LFDSearchStatus then
        MicromenuModule.originalStates.LFDSearchStatus = {
            parent = LFDSearchStatus:GetParent(),
            points = {}
        }
        for i = 1, LFDSearchStatus:GetNumPoints() do
            local point, relativeTo, relativePoint, x, y = LFDSearchStatus:GetPoint(i)
            table.insert(MicromenuModule.originalStates.LFDSearchStatus.points, {point, relativeTo, relativePoint, x, y})
        end
    end
end

local function RestoreMicromenuSystem()
    if not MicromenuModule.applied then
        return
    end

    -- Unregister all state drivers
    for name, data in pairs(MicromenuModule.stateDrivers) do
        if data.frame then
            if InCombatLockdown() then
                if addon.CombatQueue then
                    addon.CombatQueue:Add("micromenu_restore_state_driver_" .. tostring(name), function()
                        if data.frame and data.state then
                            UnregisterStateDriver(data.frame, data.state)
                        end
                    end)
                end
            else
                UnregisterStateDriver(data.frame, data.state)
            end
        end
    end
    MicromenuModule.stateDrivers = {}

    -- Restore micro buttons to original state
    for _, button in pairs(MICRO_BUTTONS) do
        if button then
            local buttonName = button:GetName()
            local original = MicromenuModule.originalStates[buttonName]

            if original then
                -- Restore SetPoint function if it was nooped
                if original.SetPoint then
                    button.SetPoint = original.SetPoint
                end

                -- Restore parent
                if original.parent then
                    button:SetParent(original.parent)
                end

                -- Clear and restore points
                button:ClearAllPoints()
                for _, pointData in ipairs(original.points) do
                    local point, relativeTo, relativePoint, x, y = unpack(pointData)
                    if relativeTo then
                        button:SetPoint(point, relativeTo, relativePoint, x, y)
                    else
                        button:SetPoint(point, relativePoint, x, y)
                    end
                end

                -- Restore size
                if original.size then
                    button:SetSize(unpack(original.size))
                end

                -- Restore textures
                if original.textures then
                    if original.textures.normal and button:GetNormalTexture() then
                        button:GetNormalTexture():SetTexture(original.textures.normal)
                    end
                    if original.textures.pushed and button:GetPushedTexture() then
                        button:GetPushedTexture():SetTexture(original.textures.pushed)
                    end
                    if original.textures.highlight and button:GetHighlightTexture() then
                        button:GetHighlightTexture():SetTexture(original.textures.highlight)
                    end
                    if original.textures.disabled and button:GetDisabledTexture() then
                        button:GetDisabledTexture():SetTexture(original.textures.disabled)
                    end
                end

                -- Restore scripts
                if original.scripts then
                    for scriptName, scriptFunc in pairs(original.scripts) do
                        button:SetScript(scriptName, scriptFunc)
                    end
                end

                -- Clean up DragonUI custom textures
                if button.DragonUIBackground then
                    button.DragonUIBackground:Hide()
                    button.DragonUIBackground = nil
                end
                if button.DragonUIBackgroundPushed then
                    button.DragonUIBackgroundPushed:Hide()
                    button.DragonUIBackgroundPushed = nil
                end
                if button.DragonUICharHighlight then
                    button.DragonUICharHighlight:Hide()
                    button.DragonUICharHighlight = nil
                end
                if button.DragonUIPVPIcon then
                    button.DragonUIPVPIcon:Hide()
                    button.DragonUIPVPIcon = nil
                end

                if button == _G.CharacterMicroButton and MicroButtonPortrait then
                    MicroButtonPortrait:Show()
                    MicroButtonPortrait:SetAlpha(1)
                end

                button.dragonUIState = nil
                button.dragonUITimer = nil
                button.dragonUILastState = nil
                button.HandleDragonUIState = nil
            end
        end
    end

    -- Restore MainMenuBarBackpackButton
    if MicromenuModule.originalStates.MainMenuBarBackpackButton then
        local original = MicromenuModule.originalStates.MainMenuBarBackpackButton

        if original.SetPoint then
            MainMenuBarBackpackButton.SetPoint = original.SetPoint
        end

        if original.parent then
            MainMenuBarBackpackButton:SetParent(original.parent)
        end

        MainMenuBarBackpackButton:ClearAllPoints()
        for _, pointData in ipairs(original.points) do
            local point, relativeTo, relativePoint, x, y = unpack(pointData)
            if relativeTo then
                MainMenuBarBackpackButton:SetPoint(point, relativeTo, relativePoint, x, y)
            else
                MainMenuBarBackpackButton:SetPoint(point, relativePoint, x, y)
            end
        end

        if original.size then
            MainMenuBarBackpackButton:SetSize(unpack(original.size))
        end
    end

    -- Restore bag slots
    for idx, bagSlot in pairs(bagslots) do
        local slotName = bagSlot:GetName()
        local original = MicromenuModule.originalStates[slotName]

        if original then
            if original.parent then
                bagSlot:SetParent(original.parent)
            end

            bagSlot:ClearAllPoints()
            for _, pointData in ipairs(original.points) do
                local point, relativeTo, relativePoint, x, y = unpack(pointData)
                if relativeTo then
                    bagSlot:SetPoint(point, relativeTo, relativePoint, x, y)
                else
                    bagSlot:SetPoint(point, relativePoint, x, y)
                end
            end

            if original.size then
                bagSlot:SetSize(unpack(original.size))
            end
        end
    end

    -- Restore KeyRingButton
    if KeyRingButton and MicromenuModule.originalStates.KeyRingButton then
        local original = MicromenuModule.originalStates.KeyRingButton

        if original.parent then
            KeyRingButton:SetParent(original.parent)
        end

        KeyRingButton:ClearAllPoints()
        for _, pointData in ipairs(original.points) do
            local point, relativeTo, relativePoint, x, y = unpack(pointData)
            if relativeTo then
                KeyRingButton:SetPoint(point, relativeTo, relativePoint, x, y)
            else
                KeyRingButton:SetPoint(point, relativePoint, x, y)
            end
        end

        if original.size then
            KeyRingButton:SetSize(unpack(original.size))
        end
    end

    -- Restore LFG frame
    if MiniMapLFGFrame and MicromenuModule.originalStates.MiniMapLFGFrame then
        local original = MicromenuModule.originalStates.MiniMapLFGFrame

        MiniMapLFGFrame:ClearAllPoints()
        for _, pointData in ipairs(original.points) do
            local point, relativeTo, relativePoint, x, y = unpack(pointData)
            if relativeTo then
                MiniMapLFGFrame:SetPoint(point, relativeTo, relativePoint, x, y)
            else
                MiniMapLFGFrame:SetPoint(point, relativePoint, x, y)
            end
        end

        if original.scale then
            MiniMapLFGFrame:SetScale(original.scale)
        end

        -- Restore border
        if MiniMapLFGFrameBorder then
            MiniMapLFGFrameBorder:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        end
    end

    -- Restore LFDSearchStatus
    if LFDSearchStatus and MicromenuModule.originalStates.LFDSearchStatus then
        local original = MicromenuModule.originalStates.LFDSearchStatus

        if original.parent then
            LFDSearchStatus:SetParent(original.parent)
        end

        LFDSearchStatus:ClearAllPoints()
        for _, pointData in ipairs(original.points) do
            local point, relativeTo, relativePoint, x, y = unpack(pointData)
            if relativeTo then
                LFDSearchStatus:SetPoint(point, relativeTo, relativePoint, x, y)
            else
                LFDSearchStatus:SetPoint(point, relativePoint, x, y)
            end
        end
    end

    -- Hide custom frames
    if _G.pUiMicroMenu then
        _G.pUiMicroMenu:Hide()
    end
    if _G.pUiBagsBar then
        _G.pUiBagsBar:Hide()
    end
    if addon.pUiArrowManager then
        addon.pUiArrowManager:Hide()
    end

    -- Unregister all event frames
    for _, frame in pairs(MicromenuModule.eventFrames) do
        if frame and frame.UnregisterAllEvents then
            frame:UnregisterAllEvents()
        end
    end
    MicromenuModule.eventFrames = {}

    -- Clear module references
    MicromenuModule.frames = {}
    MicromenuModule.hooks = {}
    MicromenuModule.applied = false
    addon.ReanchorLFDSearchStatus = nil

    -- Update Blizzard UI
    if UpdateMicroButtons then
        UpdateMicroButtons()
    end
end

-- Ensure MicroButtonPortrait stays valid after Blizzard updates.
-- WeakAuras (and other addons using PlayerModel objects) can invalidate
-- portrait textures during their async initialization. By hooking
-- UpdateMicroButtons we re-apply the portrait texture every time
-- Blizzard refreshes the micro button bar.
if UpdateMicroButtons then
    hooksecurefunc("UpdateMicroButtons", function()
        UpdateCharacterPortraitVisibility()
    end)
end



local function ApplyMicromenuSystem()
    if MicromenuModule.applied or not IsModuleEnabled() then
        return
    end

    -- Store original states first
    StoreOriginalMicroButtonStates()

    -- ============================================================================
    -- SECTION 4: BAG FRAME CLEANUP
    -- ============================================================================

    local function HideUnwantedBagFrames()
        -- Process all secondary bag slots
        for i, bags in pairs(bagslots) do
            local bagName = bags:GetName()

            local possibleFrames = {bagName .. "Background", bagName .. "Border", bagName .. "Frame",
                                    bagName .. "Texture", bagName .. "NormalTexture", bagName .. "Highlight", bagName .. "Glow", bagName .. "Green",
                                    bagName .. "NormalTexture2", bagName .. "IconBorder", bagName .. "Flash",
                                    bagName .. "NewItemTexture", bagName .. "Shine", bagName .. "NewItemGlow"}

            for _, frameName in pairs(possibleFrames) do
                local frame = _G[frameName]
                if frame and frame.Hide then
                    frame:Hide()
                    if frame.SetAlpha then
                        frame:SetAlpha(0)
                    end
                end
            end

            local normalTexture = bags:GetNormalTexture()
            if normalTexture then
                normalTexture:SetAlpha(0)
                normalTexture:Hide()
            end

            -- Hide problematic texture regions
            local numRegions = bags:GetNumRegions()
            for j = 1, numRegions do
                local region = select(j, bags:GetRegions())
                if region and region:GetObjectType() == "Texture" then
                    -- Keep DragonUI managed textures visible; only suppress
                    -- Blizzard default layers.
                    if region == bags.customBorder or region == bags.background then
                        region:Show()
                        if region.SetAlpha then
                            region:SetAlpha(1)
                        end
                    else
                    local texture = region:GetTexture()
                    if texture then
                        local textureLower = tostring(texture):lower()
                        
                        -- Skip item icons - don't hide them
                        if textureLower:find("interface\\icons\\") then
                            -- This is an item icon - don't hide it
                        else
                            -- Hide only UI elements, not icons
                            if textureLower:find("background") or textureLower:find("border") or textureLower:find("frame") or
                                textureLower:find("highlight") or textureLower:find("green") or textureLower:find("glow") or
                                textureLower:find("flash") or textureLower:find("shine") then
                                region:Hide()
                                if region.SetAlpha then
                                    region:SetAlpha(0)
                                end
                            end
                        end
                    end
                    end
                end
            end
        end

        -- Handle KeyRing with same approach
        if KeyRingButton then
            local keyRingName = KeyRingButton:GetName()
            local possibleFrames = {keyRingName .. "Background", keyRingName .. "Border", keyRingName .. "Frame",
                                    keyRingName .. "Texture", keyRingName .. "Highlight", keyRingName .. "Glow",
                                    keyRingName .. "Green", keyRingName .. "NormalTexture2",
                                    keyRingName .. "IconBorder", keyRingName .. "Flash", keyRingName .. "Shine",
                                    keyRingName .. "NewItemGlow"}

            for _, frameName in pairs(possibleFrames) do
                local frame = _G[frameName]
                if frame and frame.Hide then
                    frame:Hide()
                    if frame.SetAlpha then
                        frame:SetAlpha(0)
                    end
                end
            end
        end
    end

    -- Frame cleanup scheduler (debounced).
    -- Collapses multiple calls within a burst into a single execution at the
    -- earliest requested time. Prevents redundant region scans when several
    -- callers schedule cleanup in quick succession.
    local hideFramesScheduler = CreateFrame("Frame")
    local hidePendingTime = nil

    local function ScheduleHideFrames(delay)
        local target = GetTime() + (delay or 0)
        if hidePendingTime and hidePendingTime <= target then
            return -- an earlier execution is already pending
        end
        hidePendingTime = target

        if not hideFramesScheduler:GetScript("OnUpdate") then
            hideFramesScheduler:SetScript("OnUpdate", function(self)
                if hidePendingTime and GetTime() >= hidePendingTime then
                    HideUnwantedBagFrames()
                    hidePendingTime = nil
                    self:SetScript("OnUpdate", nil)
                end
            end)
        end
    end

    -- Character/PVP are special: their panel-open state may not always map to
    -- transient GetButtonState()=="PUSHED", so include checked/open-state signals.
    local function IsSpecialMicroButtonActive(button, buttonName)
        if not button then return false end

        local pressed = button.GetButtonState and button:GetButtonState() == "PUSHED"
        local checked = button.GetChecked and button:GetChecked()

        if buttonName == "Character" then
            -- Use ONLY panel visibility. GetButtonState/GetChecked cause false
            -- positives: GetButtonState is PUSHED while holding the mouse (before
            -- OnClick opens the frame), GetChecked may be stale from portrait loading.
            return (_G.CharacterFrame and _G.CharacterFrame:IsVisible() and true or false)
                or (_G.PaperDollFrame and _G.PaperDollFrame:IsVisible() and true or false)
        elseif buttonName == "PVP" then
            -- In WotLK 3.3.5a, GetChecked() on PVPMicroButton returns true when
            -- the player has their PvP flag enabled - NOT when the panel is open.
            -- Using it would permanently dim the icon on PvP servers.
            -- GetButtonState() == "PUSHED" is also unreliable here.
            -- Only use actual panel-frame visibility as the active signal.
            return (_G.PVPFrame and _G.PVPFrame:IsVisible() and true or false)
                or (_G.PVPParentFrame and _G.PVPParentFrame:IsVisible() and true or false)
                or (_G.BattlefieldFrame and _G.BattlefieldFrame:IsVisible() and true or false)
                or (_G.HonorFrame and _G.HonorFrame:IsVisible() and true or false)
        end

        return pressed
    end

    -- ============================================================================
    -- SECTION 5: SPECIALIZED BUTTON SETUP
    -- ============================================================================
    local function SetupPVPButton(button)
        -- Mirror the Character button pattern:
        -- Instead of fighting WoW's internal NormalTexture alpha management,
        -- we create our own ARTWORK texture (DragonUIPVPIcon) that we control
        -- exclusively, just like Character uses MicroButtonPortrait.
        local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\micropvp'
        local englishFaction = UnitFactionGroup('player')
        local backgroundTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
        local buttonWidth, buttonHeight = button:GetSize()
        local dx, dy = -1, 1
        local offX, offY = button:GetPushedTextOffset()
        local sizeX, sizeY = buttonWidth, buttonHeight

        -- ---- Icon layer: our own ARTWORK texture, never touched by WoW's button system ----
        if not button.DragonUIPVPIcon then
            local icon = button:CreateTexture(nil, 'ARTWORK')
            button.DragonUIPVPIcon = icon
        end

        local icon = button.DragonUIPVPIcon
        if englishFaction == 'Alliance' then
            icon:SetTexture(microTexture)
            icon:SetTexCoord(0, 118 / 256, 0, 151 / 256)
        elseif englishFaction == 'Horde' then
            icon:SetTexture(microTexture)
            icon:SetTexCoord(118 / 256, 236 / 256, 0, 151 / 256)
        else
            -- Faction unknown: use atlas grayscale fallback
            icon:set_atlas('ui-hud-micromenu-pvp-up-2x')
        end
        icon:ClearAllPoints()
        icon:SetPoint('CENTER', button, 'CENTER', 0, 0)
        icon:SetSize(buttonWidth, buttonHeight)
        icon:SetAlpha(1.0)
        icon:Show()

        -- ---- Hover highlight: reuse GetHighlightTexture() with faction texture + BlendMode ADD
        -- WoW shows/hides this automatically on mouse enter/leave.
        local highlightTexture = button:GetHighlightTexture()
        if highlightTexture then
            if englishFaction == 'Alliance' then
                highlightTexture:SetTexture(microTexture)
                highlightTexture:SetTexCoord(0, 118 / 256, 0, 151 / 256)
            elseif englishFaction == 'Horde' then
                highlightTexture:SetTexture(microTexture)
                highlightTexture:SetTexCoord(118 / 256, 236 / 256, 0, 151 / 256)
            else
                highlightTexture:set_atlas('ui-hud-micromenu-pvp-mouseover-2x')
            end
            highlightTexture:ClearAllPoints()
            highlightTexture:SetAllPoints(button)
            highlightTexture:SetBlendMode('ADD')
            highlightTexture:SetAlpha(0.5)
        end

        -- ---- Background slot texture ----
        if not button.DragonUIBackground then
            local bg = button:CreateTexture(nil, 'BACKGROUND')
            bg:SetTexture(backgroundTexture)
            bg:SetSize(sizeX, sizeY + 1)
            bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
            bg:SetPoint('CENTER', dx, dy)
            button.DragonUIBackground = bg

            local bgPushed = button:CreateTexture(nil, 'BACKGROUND')
            bgPushed:SetTexture(backgroundTexture)
            bgPushed:SetSize(sizeX, sizeY + 1)
            bgPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
            bgPushed:SetPoint('CENTER', dx + offX, dy + offY)
            bgPushed:Hide()
            button.DragonUIBackgroundPushed = bgPushed
        else
            button.DragonUIBackground:SetTexture(backgroundTexture)
            button.DragonUIBackground:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
            button.DragonUIBackground:ClearAllPoints()
            button.DragonUIBackground:SetPoint('CENTER', dx, dy)
            button.DragonUIBackground:SetSize(sizeX, sizeY + 1)

            if button.DragonUIBackgroundPushed then
                button.DragonUIBackgroundPushed:SetTexture(backgroundTexture)
                button.DragonUIBackgroundPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
                button.DragonUIBackgroundPushed:ClearAllPoints()
                button.DragonUIBackgroundPushed:SetPoint('CENTER', dx + offX, dy + offY)
                button.DragonUIBackgroundPushed:SetSize(sizeX, sizeY + 1)
            end
        end

        -- ---- State tracking ----
        button.dragonUIState = button.dragonUIState or {}
        button.dragonUIState.pushed = IsSpecialMicroButtonActive(button, "PVP")
        button.dragonUILastState = button.dragonUIState.pushed
        button.dragonUITimer = button.dragonUITimer or 0

        -- ---- State handler: only manipulates DragonUIPVPIcon ----
        button.HandleDragonUIState = function()
            local pvpIcon = button.DragonUIPVPIcon
            local state = button.dragonUIState
            local hlTex = button:GetHighlightTexture()
            if state and state.pushed then
                if pvpIcon then
                    pvpIcon:ClearAllPoints()
                    pvpIcon:SetPoint('CENTER', button, 'CENTER', offX, offY)
                    pvpIcon:SetAlpha(0.7)
                end
                if button.DragonUIBackground then
                    button.DragonUIBackground:Hide()
                end
                if button.DragonUIBackgroundPushed then
                    button.DragonUIBackgroundPushed:Show()
                end
                -- Shift highlight to match icon pushed displacement
                if hlTex then
                    hlTex:ClearAllPoints()
                    hlTex:SetPoint('TOPLEFT', button, 'TOPLEFT', offX, offY)
                    hlTex:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', offX, offY)
                end
            else
                if pvpIcon then
                    pvpIcon:ClearAllPoints()
                    pvpIcon:SetPoint('CENTER', button, 'CENTER', 0, 0)
                    pvpIcon:SetAlpha(1.0)
                end
                if button.DragonUIBackground then
                    button.DragonUIBackground:Show()
                end
                if button.DragonUIBackgroundPushed then
                    button.DragonUIBackgroundPushed:Hide()
                end
                if hlTex then
                    hlTex:ClearAllPoints()
                    hlTex:SetAllPoints(button)
                end
            end
        end

        -- ---- OnUpdate: poll panel visibility ----
        button:SetScript('OnUpdate', function(self, elapsed)
            self.dragonUITimer = (self.dragonUITimer or 0) + elapsed
            if self.dragonUITimer >= 0.1 then
                self.dragonUITimer = 0
                local currentState = IsSpecialMicroButtonActive(self, "PVP")
                if currentState ~= self.dragonUILastState then
                    self.dragonUILastState = currentState
                    if self.dragonUIState then
                        self.dragonUIState.pushed = currentState
                    end
                    if self.HandleDragonUIState then
                        self.HandleDragonUIState()
                    end
                end
            end
        end)

        -- ---- Mouse feedback (immediate response on click) ----
        if not button.DragonUIStateHooks then
            button:HookScript('OnMouseDown', function(self)
                if self.dragonUIState then
                    self.dragonUIState.pushed = true
                end
                if self.HandleDragonUIState then
                    self.HandleDragonUIState()
                end
            end)
            button:HookScript('OnMouseUp', function(self)
                local currentState = IsSpecialMicroButtonActive(self, "PVP")
                self.dragonUILastState = currentState
                if self.dragonUIState then
                    self.dragonUIState.pushed = currentState
                end
                if self.HandleDragonUIState then
                    self.HandleDragonUIState()
                end
            end)
            button.DragonUIStateHooks = true
        end

        -- Apply initial state
        button.HandleDragonUIState()
    end

    -- Local flag: reset on every /reload (Lua state is wiped).
    -- Frame properties survive reload, but hooksecurefunc on globals don't.
    local charPushHooksRegistered = false

    local function SetupCharacterButton(button)
        -- STEP 1: Use Blizzard's native portrait (like RetailUI)
        local portraitTexture = MicroButtonPortrait
        if not portraitTexture then
            return
        end
        portraitTexture:ClearAllPoints()
        portraitTexture:SetPoint('CENTER', button, 'CENTER', 0, -0.5)
        portraitTexture:SetSize(18, 24)
        portraitTexture:SetAlpha(1)

        -- Hide Blizzard's native normal/pushed/highlight textures so they
        -- don't bleed through as a background after /reload.  We use our
        -- own DragonUIBackground/BackgroundPushed instead.
        local nt = button:GetNormalTexture()
        if nt then nt:SetTexture(nil) end
        local pt = button:GetPushedTexture()
        if pt then pt:SetTexture(nil) end
        local ht = button:GetHighlightTexture()
        if ht then ht:SetTexture(nil) end
        local dt = button:GetDisabledTexture()
        if dt then dt:SetTexture(nil) end

        -- STEP 2: Hover highlight — OVERLAY with ADD blend.
        -- Uses SetPortraitTexture directly (not GetTexture clone, which returns
        -- nil for 3D portrait renders). SetAllPoints(portraitTexture) guarantees
        -- identical position/size — same technique as DragonUIPortraitDim.
        local function RefreshCharHighlight(btn)
            local hl = btn.DragonUICharHighlight
            if not hl then return end
            SetPortraitTexture(hl, "player")
            hl:SetTexCoord(MicroButtonPortrait:GetTexCoord())
            hl:SetBlendMode('ADD')
            hl:SetAlpha(1)
            hl:SetAllPoints(MicroButtonPortrait)
        end

        if not button.DragonUICharHighlight then
            local hl = button:CreateTexture(nil, 'OVERLAY')
            hl:SetAllPoints(portraitTexture)
            hl:Hide()
            button.DragonUICharHighlight = hl

            button:HookScript('OnEnter', function(self)
                if self.DragonUICharHighlight then
                    RefreshCharHighlight(self)
                    self.DragonUICharHighlight:Show()
                end
            end)
            button:HookScript('OnLeave', function(self)
                if self.DragonUICharHighlight then
                    self.DragonUICharHighlight:Hide()
                end
            end)
        end

        -- Global function hooks: must re-register every reload (Lua state resets).
        -- Sync highlight TexCoord and force portrait alpha=1 so Blizzard's
        -- SetPushed/SetNormal don't darken the portrait.
        if not charPushHooksRegistered then
            hooksecurefunc('CharacterMicroButton_SetPushed', function()
                if not MicromenuModule.applied or not IsModuleEnabled() then
                    return
                end

                local isGS = addon and addon.db and addon.db.profile
                    and addon.db.profile.micromenu and addon.db.profile.micromenu.grayscale_icons
                if isGS then return end
                MicroButtonPortrait:SetAlpha(0.7)
                local nt = button:GetNormalTexture()
                if nt then nt:SetTexture(nil) end
                local pt = button:GetPushedTexture()
                if pt then pt:SetTexture(nil) end
                local hl = button.DragonUICharHighlight
                if hl and hl:IsShown() then
                    hl:SetTexCoord(MicroButtonPortrait:GetTexCoord())
                end
            end)
            hooksecurefunc('CharacterMicroButton_SetNormal', function()
                if not MicromenuModule.applied or not IsModuleEnabled() then
                    return
                end

                local isGS = addon and addon.db and addon.db.profile
                    and addon.db.profile.micromenu and addon.db.profile.micromenu.grayscale_icons
                if isGS then return end
                MicroButtonPortrait:SetAlpha(1)
                local nt = button:GetNormalTexture()
                if nt then nt:SetTexture(nil) end
                local pt = button:GetPushedTexture()
                if pt then pt:SetTexture(nil) end
                local hl = button.DragonUICharHighlight
                if hl and hl:IsShown() then
                    hl:SetTexCoord(MicroButtonPortrait:GetTexCoord())
                end
            end)
            charPushHooksRegistered = true
        end
        RefreshCharHighlight(button)
        button.DragonUICharHighlight:Hide()

        -- Keep highlight in sync when portrait model updates (first login).
        if not button.DragonUIPortraitEventRegistered then
            button:RegisterEvent("UNIT_PORTRAIT_UPDATE")
            button:HookScript("OnEvent", function(self, event, unit)
                if event == "UNIT_PORTRAIT_UPDATE" and unit == "player" then
                    local isGrayscale = addon and addon.db and addon.db.profile
                        and addon.db.profile.micromenu and addon.db.profile.micromenu.grayscale_icons
                    if isGrayscale then return end
                    RefreshCharHighlight(self)
                end
            end)
            button.DragonUIPortraitEventRegistered = true
        end

        -- STEP 3: Background only (like other buttons)
        if not button.DragonUIBackground then
            local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
            local dx, dy = -1, 1
            local offX, offY = button:GetPushedTextOffset()
            local sizeX, sizeY = button:GetSize()

            local bg = button:CreateTexture(nil, 'BACKGROUND')
            bg:SetTexture(microTexture)
            bg:SetSize(sizeX, sizeY + 1)
            bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
            bg:SetPoint('CENTER', dx, dy)
            button.DragonUIBackground = bg

            local bgPushed = button:CreateTexture(nil, 'BACKGROUND')
            bgPushed:SetTexture(microTexture)
            bgPushed:SetSize(sizeX, sizeY + 1)
            bgPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
            bgPushed:SetPoint('CENTER', dx + offX, dy + offY)
            bgPushed:Hide()
            button.DragonUIBackgroundPushed = bgPushed

            -- STEP 3: Initialize state tracking properties
            -- Always start unpushed: CharacterFrame can't be open on login/reload.
            -- The OnUpdate poll will detect it correctly after the first tick.
            button.dragonUIState = {
                pushed = false
            }
            button.dragonUITimer = 0
            button.dragonUILastState = button.dragonUIState.pushed

            button.HandleDragonUIState = function()
                local state = button.dragonUIState
                if state and state.pushed then
                    MicroButtonPortrait:SetAlpha(0.7)
                    bg:Hide()
                    bgPushed:Show()
                else
                    MicroButtonPortrait:SetAlpha(1)
                    bg:Show()
                    bgPushed:Hide()
                end
            end

            -- STEP 4: Poll CharacterFrame visibility every 100ms.
            -- Frame visibility (IsVisible) is the only reliable signal:
            -- - GetButtonState is PUSHED while holding mouse, BEFORE OnClick opens
            --   the frame, causing a premature false dim that resets on release.
            -- - Pure IsVisible polling has no false-positive risk: CharacterFrame
            --   is only visible when actually open.
            button:SetScript('OnUpdate', function(self, elapsed)
                self.dragonUITimer = (self.dragonUITimer or 0) + elapsed
                if self.dragonUITimer >= 0.1 then
                    self.dragonUITimer = 0
                    local currentState = IsSpecialMicroButtonActive(self, "Character")
                    if currentState ~= self.dragonUILastState then
                        self.dragonUILastState = currentState
                        if self.dragonUIState then
                            self.dragonUIState.pushed = currentState
                        end
                        if self.HandleDragonUIState then
                            self.HandleDragonUIState()
                        end
                    end
                end
            end)

            button.HandleDragonUIState()
        else
            -- Re-apply geometry/visibility every pass to survive late Blizzard updates.
            local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
            local dx, dy = -1, 1
            local offX, offY = button:GetPushedTextOffset()
            local sizeX, sizeY = button:GetSize()

            button.DragonUIBackground:SetTexture(microTexture)
            button.DragonUIBackground:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
            button.DragonUIBackground:ClearAllPoints()
            button.DragonUIBackground:SetPoint('CENTER', dx, dy)
            button.DragonUIBackground:SetSize(sizeX, sizeY + 1)

            if button.DragonUIBackgroundPushed then
                button.DragonUIBackgroundPushed:SetTexture(microTexture)
                button.DragonUIBackgroundPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
                button.DragonUIBackgroundPushed:ClearAllPoints()
                button.DragonUIBackgroundPushed:SetPoint('CENTER', dx + offX, dy + offY)
                button.DragonUIBackgroundPushed:SetSize(sizeX, sizeY + 1)
            end

            button.dragonUIState = button.dragonUIState or { pushed = false }

            -- Delegate to the existing handler for consistent state application
            if button.HandleDragonUIState then
                button.HandleDragonUIState()
            end
        end
    end

    -- ============================================================================
    -- SECTION 6: MAIN SETUP FUNCTIONS
    -- ============================================================================

    -- Create global bags bar
    _G.pUiBagsBar = CreateFrame('Frame', 'pUiBagsBar', UIParent);
    local pUiBagsBar = _G.pUiBagsBar;
    -- DON'T parent automatically - will be done in setup when necessary
    KeyRingButton:SetParent(_G.CharacterBag3Slot);

    function MainMenuMicroButtonMixin:bagbuttons_setup()
        MicromenuModule.hooks = MicromenuModule.hooks or {}

        -- Setup main backpack button
        MainMenuBarBackpackButton:SetSize(50, 50)
        MainMenuBarBackpackButton:SetNormalTexture(nil)
        MainMenuBarBackpackButton:SetPushedTexture(nil)
        MainMenuBarBackpackButton:SetHighlightTexture ''
        MainMenuBarBackpackButton:SetCheckedTexture ''
        do
            local ht = MainMenuBarBackpackButton:GetHighlightTexture()
            ht:SetAllPoints()
            ht:SetBlendMode('ADD')
            ht:set_atlas('bag-main-highlight-2x')
            local ct = MainMenuBarBackpackButton:GetCheckedTexture()
            ct:SetAllPoints()
            ct:SetBlendMode('ADD')
            ct:SetDrawLayer('OVERLAY', 7)
            ct:set_atlas('bag-main-highlight-2x')
        end
        MainMenuBarBackpackButtonIconTexture:set_atlas('bag-main-2x')

        -- DON'T position MainMenuBarBackpackButton here if using overlay - will be positioned by the overlay
        -- MainMenuBarBackpackButton:ClearAllPoints()
        -- MainMenuBarBackpackButton:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', 1, 41)

        MainMenuBarBackpackButtonCount:SetClearPoint('CENTER', MainMenuBarBackpackButton, 'BOTTOM', 0, 14)
        CharacterBag0Slot:SetClearPoint('RIGHT', MainMenuBarBackpackButton, 'LEFT', -14, -2)

        -- Setup KeyRingButton
        KeyRingButton:SetSize(34, 34)
        KeyRingButton:SetClearPoint('RIGHT', CharacterBag3Slot, 'LEFT', -4, 0)
        KeyRingButton:SetNormalTexture ''
        KeyRingButton:SetPushedTexture(nil)
        KeyRingButton:SetHighlightTexture ''
        KeyRingButton:SetCheckedTexture ''

        local highlight = KeyRingButton:GetHighlightTexture();
        highlight:SetAllPoints();
        highlight:SetBlendMode('ADD');
        highlight:SetAlpha(.4);
        highlight:set_atlas('bag-border-highlight-2x', true)
        KeyRingButton:GetNormalTexture():set_atlas('bag-reagent-border-2x')
        do
            local ct = KeyRingButton:GetCheckedTexture()
            ct:SetAllPoints()
            ct:SetBlendMode('ADD')
            ct:SetDrawLayer('OVERLAY', 7)
            ct:set_atlas('bag-border-highlight-2x')
        end
        -- Bagster replaces ContainerFrame_OnShow checked sync; highlight backpack/bag slots instead
        local function SyncKeyRingButton()
            if addon.BagsterModule and addon.BagsterModule.BagsterModule
                and addon.BagsterModule.BagsterModule.applied
                and addon.BagsterHighlightMainMenuBags then
                addon.BagsterHighlightMainMenuBags()
                return
            end
            if KeyRingButton then
                KeyRingButton:SetChecked(IsBagOpen(-2) and 1 or nil)
            end
        end

        if not MicromenuModule.hooks.KeyRingSyncHooks then
            hooksecurefunc("ToggleKeyRing", SyncKeyRingButton)
            hooksecurefunc("CloseAllBags", function()
                if addon.BagsterModule and addon.BagsterModule.BagsterModule
                    and addon.BagsterModule.BagsterModule.applied
                    and addon.BagsterHighlightMainMenuBags then
                    addon.BagsterHighlightMainMenuBags()
                    return
                end
                if KeyRingButton then
                    KeyRingButton:SetChecked(nil)
                end
            end)
            hooksecurefunc("ContainerFrame_OnHide", SyncKeyRingButton)
            MicromenuModule.hooks.KeyRingSyncHooks = true
        end

        local keyringIcon = KeyRingButtonIconTexture
        if keyringIcon then
            keyringIcon:ClearAllPoints()
            keyringIcon:SetPoint('TOPRIGHT', KeyRingButton, 'TOPRIGHT', -5, -2.9);
            keyringIcon:SetPoint('BOTTOMLEFT', KeyRingButton, 'BOTTOMLEFT', 2.9, 5);
            pcall(function()
                keyringIcon:SetTexCoord(.08, .92, .08, .92)
            end)
        end

        if KeyRingButtonCount then
            KeyRingButtonCount:SetClearPoint('CENTER', KeyRingButton, 'CENTER', 0, -10);
            KeyRingButtonCount:SetDrawLayer('OVERLAY')
        end

        -- Setup individual bag slots
        for _, bags in pairs(bagslots) do
            bags:SetHighlightTexture ''
            bags:SetCheckedTexture ''
            bags:SetPushedTexture(nil)
            bags:SetNormalTexture ''
            bags:SetSize(28, 28)

            local normalTexture = bags:GetNormalTexture()
            if normalTexture then
                normalTexture:SetAlpha(0)
                normalTexture:Hide()
            end

            bags:GetCheckedTexture():SetAllPoints()
            bags:GetCheckedTexture():SetBlendMode('ADD')
            bags:GetCheckedTexture():SetDrawLayer('OVERLAY', 7)
            bags:GetCheckedTexture():set_atlas('bag-border-highlight-2x')

            local highlight = bags:GetHighlightTexture();
            highlight:SetAllPoints();
            highlight:SetBlendMode('ADD');
            highlight:SetAlpha(.4);
            highlight:set_atlas('bag-border-highlight-2x', true)

            local icon = _G[bags:GetName() .. 'IconTexture']
            if icon then
                icon:ClearAllPoints()
                icon:SetPoint('TOPRIGHT', bags, 'TOPRIGHT', -5, -2.9);
                icon:SetPoint('BOTTOMLEFT', bags, 'BOTTOMLEFT', 2.9, 5);
                pcall(function()
                    icon:SetTexCoord(.08, .92, .08, .92)
                end)
            end

            if not bags.customBorder then
                bags.customBorder = bags:CreateTexture(nil, 'OVERLAY')
                bags.customBorder:SetPoint('CENTER')
                bags.customBorder:set_atlas('bag-border-2x', true)
            end
            bags.customBorder:Show()
            bags.customBorder:SetAlpha(1)

            local w, h = bags.customBorder:GetSize()
            if not bags.background then
                bags.background = bags:CreateTexture(nil, 'BACKGROUND')
                bags.background:SetSize(w, h)
                bags.background:SetPoint('CENTER')
                bags.background:SetTexture(addon._dir .. 'Bags\\bagslots2x')
                bags.background:SetTexCoord(295 / 512, 356 / 512, 64 / 128, 125 / 128)
            end
            bags.background:Show()
            bags.background:SetAlpha(1)

            local count = _G[bags:GetName() .. 'Count']
            count:SetClearPoint('CENTER', 0, -10);
            count:SetDrawLayer('OVERLAY')
        end

        if not pUiBagsBar.registeredInEditor then
            -- Calculate overlay size to exactly match the visible bag elements.
            -- Layout (right to left from backpack right edge):
            --   Backpack(50) + gap(14) + 4xBag(28)+3xgap(4) = 188
            --   + KeyRing gap(4) + KeyRing(34) = 226
            -- Keep the editor frame at max width so gaining the keyring after
            -- a reload does not shift center-anchored saved positions.
            local bagsOverlayWidth = 226
            local bagsOverlayHeight = 54

            -- Create container frame using the standard system
            local bagsFrame = addon.CreateUIFrame(bagsOverlayWidth, bagsOverlayHeight, "BagsBar")

            -- Apply position from database or use default
            local bagsConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.bagsbar
            if bagsConfig and bagsConfig.anchor then
                bagsFrame:SetPoint(bagsConfig.anchor or "BOTTOMRIGHT", UIParent, bagsConfig.anchor or "BOTTOMRIGHT",
                    bagsConfig.posX or -3, bagsConfig.posY or 45)
            else
                bagsFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -3, 45)
            end

            -- Anchor backpack to the RIGHT edge of the overlay.
            -- The backpack is 50px wide; anchoring its RIGHT to the frame's
            -- RIGHT edge aligns it flush.  All other bags chain LEFT of the
            -- backpack, so the whole row fits perfectly inside the frame.
            MainMenuBarBackpackButton:SetParent(UIParent)
            MainMenuBarBackpackButton:ClearAllPoints()
            MainMenuBarBackpackButton:SetPoint("RIGHT", bagsFrame, "RIGHT", 0, 0)

            -- Hook so bags follow the container when it moves
            bagsFrame:HookScript("OnDragStop", function(self)
                MainMenuBarBackpackButton:ClearAllPoints()
                MainMenuBarBackpackButton:SetPoint("RIGHT", self, "RIGHT", 0, 0)
            end)

            bagsFrame:HookScript("OnShow", function(self)
                MainMenuBarBackpackButton:ClearAllPoints()
                MainMenuBarBackpackButton:SetPoint("RIGHT", self, "RIGHT", 0, 0)
            end)

            -- Defensive maintenance hook. Throttled to avoid per-frame work when the
            -- backpack button is already anchored correctly.
            bagsFrame._duiBackpackCheckElapsed = 0
            bagsFrame:HookScript("OnUpdate", function(self, elapsed)
                self._duiBackpackCheckElapsed = self._duiBackpackCheckElapsed + elapsed
                if self._duiBackpackCheckElapsed < 0.2 then
                    return
                end

                self._duiBackpackCheckElapsed = 0
                if not MainMenuBarBackpackButton:GetPoint() then
                    MainMenuBarBackpackButton:ClearAllPoints()
                    MainMenuBarBackpackButton:SetPoint("RIGHT", self, "RIGHT", 0, 0)
                end
            end)

            addon:RegisterEditableFrame({
                name = "bagsbar",
                frame = bagsFrame,
                blizzardFrame = MainMenuBarBackpackButton,
                configPath = {"widgets", "bagsbar"},
                module = addon.BagsModule or {}
            })

            pUiBagsBar.registeredInEditor = true

        end

        EnsureLootAnimationToMainBag()
        HideUnwantedBagFrames()
        -- A single deferred pass handles any late-created child textures
        -- (e.g. addons styling bag slots after us). The debounced scheduler
        -- collapses any additional calls to a single execution.
        ScheduleHideFrames(1.0)
    end

    function MainMenuMicroButtonMixin:bagbuttons_reposition()
        local bagScale = addon.db and addon.db.profile and addon.db.profile.bags and addon.db.profile.bags.scale or 1.0
        MainMenuBarBackpackButton:SetScale(bagScale)

        CharacterBag0Slot:SetClearPoint('RIGHT', MainMenuBarBackpackButton, 'LEFT', -14, -2)

        if not GetBagCollapseState() then
            StopCollapsedSecondaryFade()
            -- Expanded state
            for i, bags in pairs(bagslots) do
                bags:Show()
                bags:SetAlpha(1)
                bags:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel())
                bags:SetScale(1.0)
                bags:SetSize(28, 28)

                if i == 1 then
                    -- Already positioned above
                elseif i == 2 then
                    bags:SetClearPoint('RIGHT', CharacterBag0Slot, 'LEFT', -4, 0)
                elseif i == 3 then
                    bags:SetClearPoint('RIGHT', CharacterBag1Slot, 'LEFT', -4, 0)
                elseif i == 4 then
                    bags:SetClearPoint('RIGHT', CharacterBag2Slot, 'LEFT', -4, 0)
                end

                if bags.customBorder then
                    bags.customBorder:SetAlpha(1)
                end
                if bags.background then
                    bags.background:SetAlpha(1)
                end
            end

            if KeyRingButton then
                KeyRingButton:SetClearPoint('RIGHT', CharacterBag3Slot, 'LEFT', -4, 0)
                KeyRingButton:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel())
                KeyRingButton:SetScale(1.0)
                KeyRingButton:SetSize(34, 34)
            end
        else
            -- Collapsed state - bags behind main bag
            local forceHideCollapsed = ShouldForceCollapsedSecondaryInvisible()
            if forceHideCollapsed then
                StopCollapsedSecondaryFade()
            end
            for i, bags in pairs(bagslots) do
                bags:Show()
                bags:SetAlpha(forceHideCollapsed and 0 or 1)
                bags:ClearAllPoints()
                bags:SetPoint('CENTER', MainMenuBarBackpackButton, 'CENTER', 0, 0)
                bags:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel() - 1)

                if bags.customBorder then
                    bags.customBorder:SetAlpha(forceHideCollapsed and 0 or 1)
                end
                if bags.background then
                    bags.background:SetAlpha(forceHideCollapsed and 0 or 1)
                end

                local icon = _G[bags:GetName() .. 'IconTexture']
                if icon then
                    icon:SetAlpha(forceHideCollapsed and 0 or 1)
                end
            end

            if KeyRingButton then
                KeyRingButton:ClearAllPoints()
                KeyRingButton:SetPoint('CENTER', MainMenuBarBackpackButton, 'CENTER', 0, 0)
                KeyRingButton:SetFrameLevel(MainMenuBarBackpackButton:GetFrameLevel() - 1)
            end

            if not forceHideCollapsed and addon.RefreshCollapsedSecondaryBagsVisibility and _G.pUiBagsBar then
                addon.RefreshCollapsedSecondaryBagsVisibility((_G.pUiBagsBar:GetAlpha() or 1) > 0.01)
            end
        end

    end

    function MainMenuMicroButtonMixin:bagbuttons_refresh()
        if _G.pUiBagsBar then
            for _, bags in pairs(bagslots) do
                if bags:GetParent() ~= _G.pUiBagsBar then
                    bags:SetParent(_G.pUiBagsBar);
                end
            end
        end

        self:bagbuttons_setup();

        if HasKey() then
            KeyRingButton:Show();
        else
            KeyRingButton:Hide();
        end

        -- Update bag slot icons with delayed stabilization for reload timing.
        ScheduleBagSlotIconRefreshes()

        HideUnwantedBagFrames()
    end

    -- Buttons layout as a grid; hover/combat visibility stays on pUiMicroMenu.
    local MICRO_LAYOUT_BASE_Y = 55

    local function MigrateMicroIconSpacingToPadding()
        local mm = addon.db and addon.db.profile and addon.db.profile.micromenu
        if not mm or mm.spacing_is_padding then
            return
        end
        mm.spacing_is_padding = true
        -- Old values were origin-to-origin stride; convert once to edge padding.
        if mm.grayscale and mm.grayscale.icon_spacing ~= nil then
            mm.grayscale.icon_spacing = mm.grayscale.icon_spacing - 14
        end
        if mm.normal and mm.normal.icon_spacing ~= nil then
            mm.normal.icon_spacing = mm.normal.icon_spacing - 32
        end
    end

    local function CollectPresentMicroButtons()
        local list = {}
        for i = 1, #MICRO_BUTTONS do
            if MICRO_BUTTONS[i] then
                list[#list + 1] = MICRO_BUTTONS[i]
            end
        end
        return list
    end

    local function GetMicroLayoutMetrics(config, useGrayscale, numButtons)
        local buttonWidth = useGrayscale and 14 or 32
        local buttonHeight = useGrayscale and 19 or 40
        local pad = tonumber(config.icon_spacing)
        if pad == nil then
            pad = useGrayscale and 1 or -6
        end
        local hStep = buttonWidth + pad
        local vStep = buttonHeight + pad
        local columns = math.floor(tonumber(config.columns) or 12)
        if columns < 1 then
            columns = 1
        end
        if numButtons < 1 then
            return buttonWidth, buttonHeight, hStep, vStep, 1, 1, buttonWidth, buttonHeight
        end
        if columns > numButtons then
            columns = numButtons
        end
        local rows = math.ceil(numButtons / columns)
        local totalWidth = columns * buttonWidth + (columns - 1) * pad
        local totalHeight = rows * buttonHeight + (rows - 1) * pad
        return buttonWidth, buttonHeight, hStep, vStep, columns, rows, totalWidth, totalHeight
    end

    local function LayoutMicroButtons()
        local menu = _G.pUiMicroMenu
        if not menu or not addon.db or not addon.db.profile or not addon.db.profile.micromenu then
            return
        end

        MigrateMicroIconSpacingToPadding()

        local useGrayscale = addon.db.profile.micromenu.grayscale_icons
        local config = addon.db.profile.micromenu[useGrayscale and "grayscale" or "normal"]
        if not config then
            return
        end

        local buttons = CollectPresentMicroButtons()
        local numButtons = #buttons
        if config.invert_order and numButtons > 1 then
            local reversed = {}
            for i = numButtons, 1, -1 do
                reversed[#reversed + 1] = buttons[i]
            end
            buttons = reversed
        end

        local _, _, hStep, vStep, columns, _, totalWidth, totalHeight =
            GetMicroLayoutMetrics(config, useGrayscale, numButtons)

        for i = 1, numButtons do
            local button = buttons[i]
            local idx = i - 1
            local x = (idx % columns) * hStep
            local y = MICRO_LAYOUT_BASE_Y + math.floor(idx / columns) * vStep

            if button.SetPoint == addon._noop then
                button.SetPoint = UIParent.SetPoint
            end
            button:ClearAllPoints()
            button:SetPoint("BOTTOMLEFT", menu, "BOTTOMRIGHT", x, y)
            button.SetPoint = addon._noop
        end

        local menuScale = config.scale_menu or 1
        local overlayWidth = (totalWidth + 10) * menuScale
        local overlayHeight = (totalHeight + 10) * menuScale
        local menuOffX = -(totalWidth / 2)
        local menuOffY = -(MICRO_LAYOUT_BASE_Y + totalHeight / 2)

        menu.editorOffX = menuOffX
        menu.editorOffY = menuOffY

        if menu.editorFrame and not InCombatLockdown() then
            menu.editorFrame:SetSize(overlayWidth, overlayHeight)
            menu:ClearAllPoints()
            menu:SetPoint("BOTTOMRIGHT", menu.editorFrame, "CENTER", menuOffX, menuOffY)
        end
    end

    local function setupMicroButtons(xOffset)
        MigrateMicroIconSpacingToPadding()

        local useGrayscale = addon.db.profile.micromenu.grayscale_icons
        local configMode = useGrayscale and "grayscale" or "normal"
        local config = addon.db.profile.micromenu[configMode]

        local menuScale = config.scale_menu

        local menu = _G.pUiMicroMenu
        if not menu then
            menu = CreateFrame('Frame', 'pUiMicroMenu', UIParent)
        end
        menu:SetScale(menuScale)
        menu:SetSize(10, 10)

        local presentButtons = CollectPresentMicroButtons()
        local numButtons = #presentButtons
        local _, _, _, _, _, _, totalWidth, totalHeight =
            GetMicroLayoutMetrics(config, useGrayscale, numButtons)

        local overlayWidth = (totalWidth + 10) * menuScale
        local overlayHeight = (totalHeight + 10) * menuScale

        -- Offsets must stay unscaled: WoW multiplies SetPoint by the frame's own scale.
        local menuOffX = -(totalWidth / 2)
        local menuOffY = -(MICRO_LAYOUT_BASE_Y + totalHeight / 2)

        if not menu.registeredInEditor then
            -- PATTERN: Overlay = position anchor, real UI anchored TO overlay
            -- Same as PlayerFrame, TargetFrame, CastBar, etc.
            local microMenuFrame = addon.CreateUIFrame(overlayWidth, overlayHeight, "MicroMenu")

            -- Position the OVERLAY from saved config or defaults
            local microMenuConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.micromenu
            if microMenuConfig and microMenuConfig.posX and microMenuConfig.posY then
                microMenuFrame:SetPoint(microMenuConfig.anchor or "BOTTOMRIGHT", UIParent,
                    microMenuConfig.anchor or "BOTTOMRIGHT",
                    microMenuConfig.posX, microMenuConfig.posY)
            else
                microMenuFrame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
                    xOffset + config.x_position, config.y_position)
            end

            -- Anchor the REAL menu TO the overlay (fixed offset based on button geometry)
            menu:SetParent(UIParent)
            menu:ClearAllPoints()
            menu:SetPoint("BOTTOMRIGHT", microMenuFrame, "CENTER", menuOffX, menuOffY)

            -- Store reference and offsets for re-anchoring
            menu.editorFrame = microMenuFrame
            menu.editorOffX = menuOffX
            menu.editorOffY = menuOffY

            addon:RegisterEditableFrame({
                name = "micromenu",
                frame = microMenuFrame,
                blizzardFrame = menu,
                configPath = {"widgets", "micromenu"},
                module = addon.MicroMenuModule or {},
                onHide = function()
                    -- Re-anchor menu when leaving editor mode (overlay may have been dragged)
                    menu:ClearAllPoints()
                    menu:SetPoint("BOTTOMRIGHT", microMenuFrame, "CENTER",
                        menu.editorOffX or menuOffX, menu.editorOffY or menuOffY)
                end
            })

            menu.registeredInEditor = true
        else
            -- Subsequent calls: re-anchor to existing overlay
            if menu.editorFrame then
                menu:ClearAllPoints()
                menu:SetPoint("BOTTOMRIGHT", menu.editorFrame, "CENTER", menuOffX, menuOffY)
                menu.editorFrame:SetSize(overlayWidth, overlayHeight)
                menu.editorOffX = menuOffX
                menu.editorOffY = menuOffY
            end
        end

        for i = 1, #MICRO_BUTTONS do
            local button = MICRO_BUTTONS[i]
            if button then
                local buttonName = button:GetName():gsub('MicroButton', '')
                local name = string.lower(buttonName);

                CaptureOriginalHandlers(button)

                local wasEnabled = button.IsEnabled and button:IsEnabled() or true
                local wasVisible = button.IsVisible and button:IsVisible() or true

                button:texture_strip()
                CharacterMicroButton:SetDisabledTexture ''

                button:SetParent(menu)

                if useGrayscale then
                    button:SetSize(14, 19)
                else
                    button:SetSize(32, 40)
                end

                button.SetPoint = addon._noop
                button:SetHitRectInsets(0, 0, 0, 0)

                button:EnableMouse(true)
                if button.SetEnabled and wasEnabled then
                    button:SetEnabled(true)
                end
                if wasVisible then
                    button:Show()
                end

                local isCharacterButton = (buttonName == "Character")
                local isPVPButton = (buttonName == "PVP")

                local upCoords = not isCharacterButton and not isPVPButton and GetColoredTextureCoords(name, "Up") or nil
                local shouldUseGrayscale = useGrayscale or (not isPVPButton and not upCoords and not isCharacterButton)

                if shouldUseGrayscale then
                    -- Grayscale icons
                    local normalTexture = button:GetNormalTexture()
                    local pushedTexture = button:GetPushedTexture()
                    local disabledTexture = button:GetDisabledTexture()
                    local highlightTexture = button:GetHighlightTexture()

                    -- Ensure colored-only backgrounds do not bleed into grayscale mode.
                    if button.DragonUIBackground then
                        button.DragonUIBackground:Hide()
                    end
                    if button.DragonUIBackgroundPushed then
                        button.DragonUIBackgroundPushed:Hide()
                    end
                    if button.DragonUIHover then
                        button.DragonUIHover:Hide()
                    end

                    if normalTexture then
                        normalTexture:set_atlas('ui-hud-micromenu-' .. name .. '-up-2x')
                    end
                    if pushedTexture then
                        pushedTexture:set_atlas('ui-hud-micromenu-' .. name .. '-down-2x')
                    end
                    if disabledTexture then
                        disabledTexture:set_atlas('ui-hud-micromenu-' .. name .. '-disabled-2x')
                    end
                    if highlightTexture then
                        highlightTexture:set_atlas('ui-hud-micromenu-' .. name .. '-mouseover-2x')
                    end
                elseif isPVPButton then
                    SetupPVPButton(button)
                elseif isCharacterButton then
                    SetupCharacterButton(button)
                else
                    -- Colored icons
                    local microTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'

                    local downCoords = GetColoredTextureCoords(name, "Down")
                    local disabledCoords = GetColoredTextureCoords(name, "Disabled")
                    local mouseoverCoords = GetColoredTextureCoords(name, "Mouseover")

                    if upCoords and #upCoords >= 4 then
                        local tex = button:GetNormalTexture()
                        tex:SetTexture(microTexture)
                        tex:SetTexCoord(upCoords[1], upCoords[2], upCoords[3], upCoords[4])
                        tex:ClearAllPoints()
                        tex:SetAllPoints(button)
                    end

                    if downCoords and #downCoords >= 4 then
                        local tex = button:GetPushedTexture()
                        tex:SetTexture(microTexture)
                        tex:SetTexCoord(downCoords[1], downCoords[2], downCoords[3], downCoords[4])
                        tex:ClearAllPoints()
                        tex:SetAllPoints(button)
                    end

                    if disabledCoords and #disabledCoords >= 4 then
                        local tex = button:GetDisabledTexture()
                        tex:SetTexture(microTexture)
                        tex:SetTexCoord(disabledCoords[1], disabledCoords[2], disabledCoords[3], disabledCoords[4])
                        tex:ClearAllPoints()
                        tex:SetAllPoints(button)
                    end

                    if mouseoverCoords and #mouseoverCoords >= 4 then
                        local tex = button:GetHighlightTexture()
                        tex:SetTexture(microTexture)
                        tex:SetTexCoord(mouseoverCoords[1], mouseoverCoords[2], mouseoverCoords[3], mouseoverCoords[4])
                        tex:ClearAllPoints()
                        tex:SetAllPoints(button)
                    end

                    -- Add/update background (colored mode only)
                    if not button.DragonUIBackground then
                        local backgroundTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
                        local dx, dy = -1, 1
                        local offX, offY = button:GetPushedTextOffset()
                        local sizeX, sizeY = button:GetSize()

                        -- Use anonymous textures; named globals collide across buttons.
                        local bg = button:CreateTexture(nil, 'BACKGROUND')
                        bg:SetTexture(backgroundTexture)
                        bg:SetSize(sizeX, sizeY + 1)
                        bg:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
                        bg:SetPoint('CENTER', dx, dy)
                        button.DragonUIBackground = bg

                        local bgPushed = button:CreateTexture(nil, 'BACKGROUND')
                        bgPushed:SetTexture(backgroundTexture)
                        bgPushed:SetSize(sizeX, sizeY + 1)
                        bgPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
                        bgPushed:SetPoint('CENTER', dx + offX, dy + offY)
                        bgPushed:Hide()
                        button.DragonUIBackgroundPushed = bgPushed

                        -- Initialize state tracking properties
                        button.dragonUIState = {
                            pushed = false
                        }
                        button.dragonUITimer = 0
                        button.dragonUILastState = false

                        button.HandleDragonUIState = function()
                            local state = button.dragonUIState
                            local hlTex = button:GetHighlightTexture()
                            if state and state.pushed then
                                button.DragonUIBackground:Hide()
                                button.DragonUIBackgroundPushed:Show()
                                -- Shift highlight to match pushed displacement
                                if hlTex then
                                    hlTex:ClearAllPoints()
                                    hlTex:SetPoint('TOPLEFT', button, 'TOPLEFT', offX, offY)
                                    hlTex:SetPoint('BOTTOMRIGHT', button, 'BOTTOMRIGHT', offX, offY)
                                end
                            else
                                button.DragonUIBackground:Show()
                                button.DragonUIBackgroundPushed:Hide()
                                if hlTex then
                                    hlTex:ClearAllPoints()
                                    hlTex:SetAllPoints(button)
                                end
                            end
                        end
                        button.HandleDragonUIState()

                        -- Save original OnUpdate so the Blizzard handler
                        -- (performance indicator, tooltip data, etc.) keeps
                        -- running alongside our push-state tracker.
                        local origOnUpdate = button:GetScript('OnUpdate')
                        -- Only MainMenuMicroButton has an aggressive Blizzard
                        -- OnUpdate that overwrites textures every frame.
                        local needsTextureGuard = (buttonName == "MainMenu") and origOnUpdate ~= nil
                        local cachedUpCoords, cachedDownCoords, cachedDisabledCoords, cachedMouseoverCoords
                        if needsTextureGuard then
                            cachedUpCoords = upCoords
                            cachedDownCoords = downCoords
                            cachedDisabledCoords = disabledCoords
                            cachedMouseoverCoords = mouseoverCoords
                        end

                        button:SetScript('OnUpdate', function(self, elapsed)
                            -- Ensure timer is initialized
                            if not self.dragonUITimer then
                                self.dragonUITimer = 0
                            end

                            self.dragonUITimer = self.dragonUITimer + elapsed
                            if self.dragonUITimer >= 0.1 then
                                self.dragonUITimer = 0
                                local currentState = self:GetButtonState() == "PUSHED"
                                if currentState ~= self.dragonUILastState then
                                    self.dragonUILastState = currentState
                                    if self.dragonUIState then
                                        self.dragonUIState.pushed = currentState
                                    end
                                    if self.HandleDragonUIState then
                                        self.HandleDragonUIState()
                                    end
                                end
                            end

                            -- Chain the original Blizzard OnUpdate so the
                            -- performance indicator and tooltip keep working.
                            if origOnUpdate then
                                origOnUpdate(self, elapsed)
                            end

                            -- Re-apply colored textures after Blizzard's
                            -- OnUpdate which overwrites them every frame.
                            if needsTextureGuard then
                                if cachedUpCoords then
                                    local nt = self:GetNormalTexture()
                                    if nt then
                                        nt:SetTexture(microTexture)
                                        nt:SetTexCoord(cachedUpCoords[1], cachedUpCoords[2], cachedUpCoords[3], cachedUpCoords[4])
                                    end
                                end
                                if cachedDownCoords then
                                    local pt = self:GetPushedTexture()
                                    if pt then
                                        pt:SetTexture(microTexture)
                                        pt:SetTexCoord(cachedDownCoords[1], cachedDownCoords[2], cachedDownCoords[3], cachedDownCoords[4])
                                    end
                                end
                                if cachedDisabledCoords then
                                    local dt = self:GetDisabledTexture()
                                    if dt then
                                        dt:SetTexture(microTexture)
                                        dt:SetTexCoord(cachedDisabledCoords[1], cachedDisabledCoords[2], cachedDisabledCoords[3], cachedDisabledCoords[4])
                                    end
                                end
                                if cachedMouseoverCoords then
                                    local ht = self:GetHighlightTexture()
                                    if ht then
                                        ht:SetTexture(microTexture)
                                        ht:SetTexCoord(cachedMouseoverCoords[1], cachedMouseoverCoords[2], cachedMouseoverCoords[3], cachedMouseoverCoords[4])
                                    end
                                end
                            end
                        end)

                        -- Instant push: OnMouseDown fires BEFORE Blizzard
                        -- moves the icon, so highlight shifts in sync.
                        button:HookScript("OnMouseDown", function(self)
                            if not self.dragonUIState then return end
                            -- Only act on push direction (not already pushed)
                            if not self.dragonUIState.pushed then
                                self.dragonUIState.pushed = true
                                self.dragonUILastState = true
                                if self.HandleDragonUIState then
                                    self.HandleDragonUIState()
                                end
                            end
                        end)

                        -- Instant unpush: SetButtonState hook fires right
                        -- when Blizzard internally sets NORMAL.
                        if not button.DragonUISetButtonStateHooked then
                            hooksecurefunc(button, "SetButtonState", function(self, state)
                                if state ~= "PUSHED" then
                                    -- Only act on unpush direction
                                    if self.dragonUIState and self.dragonUIState.pushed then
                                        self.dragonUIState.pushed = false
                                        self.dragonUILastState = false
                                        if self.HandleDragonUIState then
                                            self.HandleDragonUIState()
                                        end
                                    end
                                end
                            end)
                            button.DragonUISetButtonStateHooked = true
                        end
                    else
                        -- Re-apply size/position/visibility in case a late Blizzard pass altered regions.
                        local backgroundTexture = 'Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x'
                        local dx, dy = -1, 1
                        local offX, offY = button:GetPushedTextOffset()
                        local sizeX, sizeY = button:GetSize()
                        button.DragonUIBackground:SetTexture(backgroundTexture)
                        button.DragonUIBackground:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
                        button.DragonUIBackground:ClearAllPoints()
                        button.DragonUIBackground:SetPoint('CENTER', dx, dy)
                        button.DragonUIBackground:SetSize(sizeX, sizeY + 1)
                        button.DragonUIBackground:Show()

                        button.DragonUIBackgroundPushed:SetTexture(backgroundTexture)
                        button.DragonUIBackgroundPushed:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
                        button.DragonUIBackgroundPushed:ClearAllPoints()
                        button.DragonUIBackgroundPushed:SetPoint('CENTER', dx + offX, dy + offY)
                        button.DragonUIBackgroundPushed:SetSize(sizeX, sizeY + 1)
                        if button.dragonUIState and button.dragonUIState.pushed then
                            button.DragonUIBackground:Hide()
                            button.DragonUIBackgroundPushed:Show()
                        else
                            button.DragonUIBackgroundPushed:Hide()
                        end
                    end
                end

                local highlightTexture = button:GetHighlightTexture()
                if highlightTexture then
                    highlightTexture:SetBlendMode('ADD')
                    highlightTexture:SetAlpha(1)
                end

                button:EnableMouse(true)
                if button.SetEnabled and wasEnabled then
                    button:SetEnabled(true)
                end

                if buttonName ~= "Character" then
                    RestoreOriginalHandlers(button)
                end
            end
        end
        LayoutMicroButtons()
        UpdateCharacterPortraitVisibility()

        -- ====================================================================
        -- LATENCY INDICATOR (StatusBar overlay on HelpMicroButton)
        -- Green (<300ms), Yellow (300-600ms), Red (>600ms)
        -- Uses StatusBar frame with performance bar texture as vertical
        -- overlay covering the full height of HelpMicroButton.
        -- ====================================================================
        local showLatency = addon.db.profile.micromenu.show_latency_indicator
        if showLatency and HelpMicroButton then
            if not MicromenuModule.frames.latencyIndicator then
                local latencyBar = CreateFrame("StatusBar", "DragonUIPerformanceBar", HelpMicroButton)
                latencyBar.updateInterval = 0

                latencyBar:SetStatusBarTexture(addon._dir .. "Micromenu\\ui-mainmenubar-performancebar")
                latencyBar:SetStatusBarColor(0, 1, 0)
                latencyBar:GetStatusBarTexture():SetBlendMode("ADD")
                latencyBar:GetStatusBarTexture():SetDrawLayer("OVERLAY")

                -- Tooltip on hover
                latencyBar:EnableMouse(true)
                latencyBar:SetScript("OnEnter", function(self)
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    local _, _, latency = GetNetStats()
                    latency = latency or 0
                    GameTooltip:AddLine(L and L["Network"] or "Network", 1, 1, 1)
                    GameTooltip:AddDoubleLine(L and L["Latency"] or "Latency", latency .. " ms", 1, 1, 1, 1, 1, 0)
                    GameTooltip:Show()
                end)
                latencyBar:SetScript("OnLeave", function()
                    GameTooltip:Hide()
                end)

                latencyBar:SetScript("OnUpdate", function(self, elapsed)
                    if self.updateInterval > 0 then
                        self.updateInterval = self.updateInterval - elapsed
                    else
                        self.updateInterval = 10
                        local _, _, latency = GetNetStats()
                        latency = latency or 0
                        if latency > PERFORMANCEBAR_MEDIUM_LATENCY then
                            self:SetStatusBarColor(1, 0, 0)
                        elseif latency > PERFORMANCEBAR_LOW_LATENCY then
                            self:SetStatusBarColor(1, 1, 0)
                        else
                            self:SetStatusBarColor(0, 1, 0)
                        end
                    end
                end)

                MicromenuModule.frames.latencyIndicator = latencyBar
            end

            -- Size and position adapt to grayscale vs colored mode
            local bar = MicromenuModule.frames.latencyIndicator
            bar:SetParent(HelpMicroButton)
            bar:SetFrameStrata(HelpMicroButton:GetFrameStrata())
            bar:SetFrameLevel(math.max(1, HelpMicroButton:GetFrameLevel() - 1))

            local barW, barH, offX, offY
            if useGrayscale then
                barW, barH = 13, 36
                offX, offY = 0, -3
            else
                barW, barH = 22, 60
                offX, offY = 1, -6.5
            end

            bar:ClearAllPoints()
            bar:SetSize(barW, barH)
            bar:SetPoint("BOTTOM", HelpMicroButton, "BOTTOM", offX, offY)

            bar:Show()
        elseif MicromenuModule.frames.latencyIndicator then
            MicromenuModule.frames.latencyIndicator:Hide()
        end
    end

    -- ============================================================================
    -- SECTION 7: REFRESH FUNCTIONS
    -- ============================================================================

    local function updateMicroButtonSpacing()
        LayoutMicroButtons()
    end

    function addon.RefreshMicromenuSpacing()
        updateMicroButtonSpacing()
    end

    function addon.RefreshMicromenuPosition()
    if not _G.pUiMicroMenu then
        return
    end

    local menu = _G.pUiMicroMenu
    local frameInfo = addon:GetEditableFrameInfo("micromenu")
    if frameInfo and frameInfo.frame then
        -- Position the OVERLAY from saved config or defaults
        local microMenuConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.micromenu

        if microMenuConfig and microMenuConfig.posX and microMenuConfig.posY then
            frameInfo.frame:ClearAllPoints()
            frameInfo.frame:SetPoint(microMenuConfig.anchor or "BOTTOMRIGHT", UIParent,
                microMenuConfig.anchor or "BOTTOMRIGHT",
                microMenuConfig.posX, microMenuConfig.posY)
        else
            local useGrayscale = addon.db.profile.micromenu.grayscale_icons
            local configMode = useGrayscale and "grayscale" or "normal"
            local config = addon.db.profile.micromenu[configMode]
            local xOffset = IsAddOnLoaded('ezCollections') and -180 or -166

            frameInfo.frame:ClearAllPoints()
            frameInfo.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT",
                xOffset + config.x_position, config.y_position)
        end

        -- Re-anchor menu TO the overlay using stored offsets (unscaled; WoW applies frame scale automatically)
        local offX = menu.editorOffX or -(159)
        local offY = menu.editorOffY or -(75)
        menu:ClearAllPoints()
        menu:SetPoint("BOTTOMRIGHT", frameInfo.frame, "CENTER", offX, offY)
    else
        -- Fallback: no editor frame registered yet
        local useGrayscale = addon.db.profile.micromenu.grayscale_icons
        local configMode = useGrayscale and "grayscale" or "normal"
        local config = addon.db.profile.micromenu[configMode]

        menu:SetScale(config.scale_menu)
        local xOffset = IsAddOnLoaded('ezCollections') and -180 or -166
        menu:ClearAllPoints()
        menu:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMRIGHT',
            xOffset + config.x_position, config.y_position)
    end

    updateMicroButtonSpacing()
end

    function addon.RefreshBagsPosition()
        if not _G.pUiBagsBar then
            return
        end

        local scale = addon.db and addon.db.profile and addon.db.profile.bags and addon.db.profile.bags.scale
        if scale then
            _G.pUiBagsBar:SetScale(scale)
            MainMenuBarBackpackButton:SetScale(scale)
        end

        local frameInfo = addon:GetEditableFrameInfo("bagsbar")
        if frameInfo and frameInfo.frame then
            -- Apply position from database or use default
            local bagsConfig = addon.db and addon.db.profile.widgets and addon.db.profile.widgets.bagsbar
            if bagsConfig and bagsConfig.anchor then
                frameInfo.frame:ClearAllPoints()
                frameInfo.frame:SetPoint(bagsConfig.anchor or "BOTTOMRIGHT", UIParent,
                    bagsConfig.anchor or "BOTTOMRIGHT", bagsConfig.posX or -3, bagsConfig.posY or 45)
            else
                frameInfo.frame:ClearAllPoints()
                frameInfo.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -3, 45)
            end

            -- Ensure bags follow the container — backpack flush to the
            -- RIGHT edge, all other bags chain leftward from it.
            MainMenuBarBackpackButton:ClearAllPoints()
            MainMenuBarBackpackButton:SetPoint("RIGHT", frameInfo.frame, "RIGHT", 0, 0)
        else
            -- Fallback to previous method if no container
            if not addon.db or not addon.db.profile or not addon.db.profile.bags then
                return
            end

            local bagsConfig = addon.db.profile.bags
            _G.pUiBagsBar:SetScale(bagsConfig.scale)

            local originalSetPoint = MainMenuBarBackpackButton.SetPoint
            if MainMenuBarBackpackButton.SetPoint == addon._noop then
                MainMenuBarBackpackButton.SetPoint = UIParent.SetPoint
            end

            MainMenuBarBackpackButton:ClearAllPoints()
            MainMenuBarBackpackButton:SetPoint('BOTTOMRIGHT', UIParent, 'BOTTOMRIGHT', bagsConfig.x_position,
                bagsConfig.y_position)

            if originalSetPoint == addon._noop then
                MainMenuBarBackpackButton.SetPoint = originalSetPoint
            end
        end
    end

    function addon.RefreshMicromenuVehicle()
        if not _G.pUiMicroMenu then
            return
        end

        if InCombatLockdown() then
            if addon.CombatQueue then
                addon.CombatQueue:Add("micromenu_refresh_vehicle", addon.RefreshMicromenuVehicle)
            end
            return
        end

        if addon.db.profile.micromenu.hide_on_vehicle then
            RegisterStateDriver(_G.pUiMicroMenu, 'visibility', '[vehicleui] hide;show')
        else
            UnregisterStateDriver(_G.pUiMicroMenu, 'visibility')
        end
    end

    function addon.RefreshBagsVehicle()
        if not _G.pUiBagsBar then
            return
        end

        if InCombatLockdown() then
            if addon.CombatQueue then
                addon.CombatQueue:Add("micromenu_refresh_bags_vehicle", addon.RefreshBagsVehicle)
            end
            return
        end

        if addon.db.profile.micromenu.hide_on_vehicle then
            RegisterStateDriver(_G.pUiBagsBar, 'visibility', '[vehicleui] hide;show')
        else
            UnregisterStateDriver(_G.pUiBagsBar, 'visibility')
        end
    end

    function addon.RefreshMicromenuIcons()
        -- Icon refresh handled in main setup
    end

    function addon.RefreshMicromenu()
    if not addon.db or not addon.db.profile or not addon.db.profile.micromenu then
        return
    end

    if not _G.pUiMicroMenu then
        return
    end

    local useGrayscale = addon.db.profile.micromenu.grayscale_icons
    local configMode = useGrayscale and "grayscale" or "normal"
    local config = addon.db.profile.micromenu[configMode]

    -- FIXED: Only apply scale, NOT position (editor handles that)
    _G.pUiMicroMenu:SetScale(config.scale_menu)

    -- REMOVED: Don't overwrite editor position
    -- _G.pUiMicroMenu:ClearAllPoints()
    -- _G.pUiMicroMenu:SetPoint('BOTTOMLEFT', UIParent, 'BOTTOMRIGHT', xOffset + config.x_position, config.y_position)

    addon.RefreshMicromenuIcons()

    LayoutMicroButtons()

    addon.RefreshMicromenuVehicle()
    UpdateCharacterPortraitVisibility()
end

    function addon.RefreshBags()
        if not _G.pUiBagsBar then
            return
        end

        addon.RefreshBagsPosition();

        if MainMenuMicroButtonMixin.bagbuttons_refresh then
            MainMenuMicroButtonMixin:bagbuttons_refresh();
        end

        if addon.pUiArrowManager then
            local arrow = addon.pUiArrowManager
            local isCollapsed = GetBagCollapseState()
            local normal = arrow:GetNormalTexture()
            local pushed = arrow:GetPushedTexture()
            local highlight = arrow:GetHighlightTexture()

            if isCollapsed then
                normal:set_atlas('bag-arrow-2x')
                pushed:set_atlas('bag-arrow-2x')
                highlight:set_atlas('bag-arrow-2x')
                arrow:SetChecked(true)
            else
                normal:set_atlas('bag-arrow-invert-2x')
                pushed:set_atlas('bag-arrow-invert-2x')
                highlight:set_atlas('bag-arrow-invert-2x')
                arrow:SetChecked(nil)
            end
        end

        MainMenuMicroButtonMixin:bagbuttons_reposition()
        addon.RefreshBagsVehicle();
    end

    -- ============================================================================
    -- SECTION 8: SPECIAL UI ELEMENTS
    -- ============================================================================

    -- Collapse arrow
    do
        local arrow = CreateFrame('CheckButton', 'pUiArrowManager', MainMenuBarBackpackButton)
        addon.pUiArrowManager = arrow
        arrow:SetSize(12, 18)
        arrow:SetPoint('RIGHT', MainMenuBarBackpackButton, 'LEFT', 0, -2)
        arrow:SetNormalTexture ''
        arrow:SetPushedTexture ''
        arrow:SetHighlightTexture ''
        arrow:RegisterForClicks('LeftButtonUp')

        local normal = arrow:GetNormalTexture()
        local pushed = arrow:GetPushedTexture()
        local highlight = arrow:GetHighlightTexture()

        arrow:SetScript('OnClick', function(self)
            local checked = self:GetChecked();
            if checked then
                normal:set_atlas('bag-arrow-2x')
                pushed:set_atlas('bag-arrow-2x')
                highlight:set_atlas('bag-arrow-2x')
                SetBagCollapseState(true)
                MainMenuMicroButtonMixin:bagbuttons_reposition()
            else
                normal:set_atlas('bag-arrow-invert-2x')
                pushed:set_atlas('bag-arrow-invert-2x')
                highlight:set_atlas('bag-arrow-invert-2x')
                SetBagCollapseState(false)
                MainMenuMicroButtonMixin:bagbuttons_reposition()
                UpdateBagSlotAlpha()
                ScheduleBagSlotIconRefreshes()
            end
        end)
    end

    -- LFG Frame customization
    local function ApplyLFGFrameStyle()
        MiniMapLFGFrameIcon:SetScale(1.5)
        MiniMapLFGFrameBorder:SetTexture(nil)
        MiniMapLFGFrame.eye.texture:SetTexture(addon._dir .. 'Micromenu\\uigroupfinderflipbookeye.tga')
    end

    ApplyLFGFrameStyle()

    MiniMapLFGFrame:SetScript('OnClick', function(self, button)
        local mode, submode = GetLFGMode();
        if (button == "RightButton" or mode == "lfgparty" or mode == "abandonedInDungeon") then
            PlaySound("igMainMenuOpen");
            local yOffset;
            if (mode == "queued") then
                MiniMapLFGFrameDropDown.point = "BOTTOMRIGHT";
                MiniMapLFGFrameDropDown.relativePoint = "TOPLEFT";
                yOffset = 0;
            else
                MiniMapLFGFrameDropDown.point = nil;
                MiniMapLFGFrameDropDown.relativePoint = nil;
                yOffset = 30;
            end
            ToggleDropDownMenu(1, nil, MiniMapLFGFrameDropDown, "MiniMapLFGFrame", 0, yOffset);
        elseif (mode == "proposal") then
            if (not LFDDungeonReadyPopup:IsShown()) then
                PlaySound("igCharacterInfoTab");
                StaticPopupSpecial_Show(LFDDungeonReadyPopup);
            end
        elseif (mode == "queued" or mode == "rolecheck") then
            ToggleLFDParentFrame();
        elseif (mode == "listed") then
            ToggleLFRParentFrame();
        end
    end)

    -- Keep Blizzard's LFD status text/layout ownership intact. We only
    -- re-anchor around the eye and avoid reparenting to prevent text regressions.
    local function ReanchorLFDStatus()
        if not LFDSearchStatus or not MiniMapLFGFrame then
            return
        end
        local point, relativePoint, xOff, yOff = GetLFDStatusAnchorSpec(GetLFGTooltipPosition())
        LFDSearchStatus:ClearAllPoints()
        LFDSearchStatus:SetPoint(point, MiniMapLFGFrame, relativePoint, xOff, yOff)
    end

    addon.ReanchorLFDSearchStatus = ReanchorLFDStatus

    ReanchorLFDStatus()
    if not MicromenuModule.hooks.LFDSearchStatus_Update then
        hooksecurefunc("LFDSearchStatus_Update", ReanchorLFDStatus)
        MicromenuModule.hooks.LFDSearchStatus_Update = true
    end

    -- ============================================================================
    -- SECTION 9: EVENT HANDLERS
    -- ============================================================================

    addon.package:RegisterEvents(function(self, event)
        if not IsModuleEnabled() then return end

        if event == 'BAG_UPDATE' then
            -- BAG_UPDATE fires frequently (e.g. every time ammo is consumed).
            -- Blizzard updates IconTexture automatically; only toggle KeyRing
            -- visibility and refresh slot alpha here.
            if HasKey() then
                if not KeyRingButton:IsShown() then
                    KeyRingButton:Show();
                end
            else
                if KeyRingButton:IsShown() then
                    KeyRingButton:Hide();
                end
            end

            UpdateBagSlotAlpha()
        end
    end, 'BAG_UPDATE');

    addon.package:RegisterEvents(function(self, event)
        if not IsModuleEnabled() then return end

        ScheduleBagSlotIconRefreshes()

        if KeyRingButton and HasKey() then
            KeyRingButton:Show()
        end

        HideUnwantedBagFrames()
    end, 'PLAYER_ENTERING_WORLD');

    -- NOTE: equipped-bag slot icons do not change when bag contents change;
    -- PLAYER_EQUIPMENT_CHANGED handles real bag swaps and triggers the full
    -- icon refresh there. The BAG_UPDATE handler above is intentionally
    -- lightweight to avoid unnecessary work on frequent inventory events.

    addon.package:RegisterEvents(function()
        local xOffset
        if IsAddOnLoaded('ezCollections') then
            xOffset = -180
            if _G.CollectionsMicroButton then
                _G.CollectionsMicroButton:UnregisterEvent('UPDATE_BINDINGS')
            end
        else
            xOffset = -166
        end

        setupMicroButtons(xOffset);

        if addon.RefreshBags then
            addon.RefreshBags();
        end

        addon.core:ScheduleTimer(function()
            -- Check if frames need to be registered
            if _G.pUiMicroMenu and not _G.pUiMicroMenu.registeredInEditor then
                -- Force re-setup to register frames
                setupMicroButtons(xOffset)
            end

            if _G.pUiBagsBar and not _G.pUiBagsBar.registeredInEditor then
                -- Force bags setup
                if MainMenuMicroButtonMixin.bagbuttons_setup then
                    MainMenuMicroButtonMixin:bagbuttons_setup()
                end
            end
        end, 0.5)
    end, 'PLAYER_LOGIN');

    -- Mark as applied
    MicromenuModule.applied = true

    -- Execute setup immediately only after login; pre-login passes can produce transient bad geometry.
    if IsLoggedIn() then
        local xOffset
        if IsAddOnLoaded('ezCollections') then
            xOffset = -180
            if _G.CollectionsMicroButton then
                _G.CollectionsMicroButton:UnregisterEvent('UPDATE_BINDINGS')
            end
        else
            xOffset = -166
        end

        setupMicroButtons(xOffset)

        if MainMenuMicroButtonMixin.bagbuttons_setup then
            MainMenuMicroButtonMixin:bagbuttons_setup()
        end

        if addon.RefreshBags then
            addon.RefreshBags()
        end

        if addon.RefreshMicromenu then
            addon.RefreshMicromenu()
        end

        -- Late stabilization pass for startup race conditions.
        addon.core:ScheduleTimer(function()
            if IsModuleEnabled() then
                setupMicroButtons(xOffset)
                if addon.RefreshMicromenu then addon.RefreshMicromenu() end
                if addon.RefreshBags then addon.RefreshBags() end
            end
        end, 0.2)
    end

    -- Setup all hooks
    if not MicromenuModule.hooks.MiniMapLFG_UpdateIsShown then
        MicromenuModule.hooks.MiniMapLFG_UpdateIsShown = true
        hooksecurefunc('MiniMapLFG_UpdateIsShown', function()
            if IsModuleEnabled() then
                ApplyLFGFrameStyle()
            end
        end)
    end

    -- Register all events
    -- NOTE: BAG_UPDATE is handled in SECTION 9 above. A second registration
    -- for the same event is intentionally omitted here to avoid duplicate
    -- work per inventory event.

    local eventFrame3 = MicromenuModule.eventFrames.playerEquipmentChanged or CreateFrame("Frame")
    MicromenuModule.eventFrames.playerEquipmentChanged = eventFrame3
    addon.package:RegisterEvents(function(self, event, slotID)
        if not IsModuleEnabled() then return end

        -- Bag slot swaps (equipped container changes) must refresh icons explicitly.
        -- Container 0 is the backpack (no inventory slot); equipped bags are 1-4.
        if slotID and slotID >= ContainerIDToInventoryID(1) and slotID <= ContainerIDToInventoryID(4) then
            if MainMenuMicroButtonMixin.bagbuttons_setup then
                MainMenuMicroButtonMixin:bagbuttons_setup()
            end
            RefreshBagSlotIcons()
            UpdateBagSlotAlpha()
            HideUnwantedBagFrames()
        end
    end, 'PLAYER_EQUIPMENT_CHANGED')
end

-- ============================================================================
-- PUBLIC API
-- ============================================================================

function addon.RefreshMicromenuSystem()
    if IsModuleEnabled() then
        if not MicromenuModule.applied then
            ApplyMicromenuSystem()
        end
        -- Refresh settings if already applied
        if addon.RefreshMicromenu then
            addon.RefreshMicromenu()
        end
        if addon.RefreshBags then
            addon.RefreshBags()
        end
    else
        if addon:ShouldDeferModuleDisable("micromenu", MicromenuModule) then
            return
        end
        RestoreMicromenuSystem()
    end
end

-- Keep all the existing refresh functions as they are
-- They will only work when the module is enabled
-- ============================================================================
-- Function to load default widget settings
-- ============================================================================

local function LoadDefaultWidgetSettings()
    -- Ensure widget configuration exists
    if not addon.db.profile.widgets then
        addon.db.profile.widgets = {}
    end

    if not addon.db.profile.widgets.micromenu then
        -- Calculate default position based on current configuration
        local useGrayscale = addon.db.profile.micromenu and addon.db.profile.micromenu.grayscale_icons
        local configMode = useGrayscale and "grayscale" or "normal"
        local config = addon.db.profile.micromenu and addon.db.profile.micromenu[configMode]

        if config then
            local xOffset = IsAddOnLoaded('ezCollections') and -180 or -166
            addon.db.profile.widgets.micromenu = {
                anchor = "BOTTOMRIGHT",
                posX = xOffset + config.x_position,
                posY = config.y_position
            }
        else
            -- Absolute fallback
            addon.db.profile.widgets.micromenu = {
                anchor = "BOTTOMRIGHT",
                posX = -166,
                posY = 4
            }
        end
    end
end
-- ============================================================================
-- INITIALIZATION
-- ============================================================================

local function Initialize()
    if MicromenuModule.initialized then
        return
    end

    -- Ensure default widget coordinates exist before module setup runs.
    LoadDefaultWidgetSettings()

    -- Only apply if module is enabled
    if IsModuleEnabled() then
        -- Wait for PLAYER_LOGIN to apply system
        addon.package:RegisterEvents(function()
            ApplyMicromenuSystem()
        end, 'PLAYER_LOGIN')
    end

    MicromenuModule.initialized = true
end

-- Auto-initialize when addon loads
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, addonName)
    if addonName == "DragonUI" then
        Initialize()
        self:UnregisterAllEvents()
    end
end)
