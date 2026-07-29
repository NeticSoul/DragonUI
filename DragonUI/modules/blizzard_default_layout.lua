local addon = select(2, ...)
local _G = _G

-- ============================================================================
-- BLIZZARD NATIVE LAYOUT / DRAGONUI SKIN
-- ============================================================================
-- Blizzard retains frame ownership, visibility, paging, and secure state.
-- DragonUI applies compact geometry and chrome without moving Blizzard's
-- animation-owned MainMenuBar root.

local Layout = addon.BlizzardDefaultLayout or {}
addon.BlizzardDefaultLayout = Layout

local DARK_R, DARK_G, DARK_B = 0.15, 0.15, 0.15
local BOTTOM_COMPLEX_OFFSET_Y = 10
local BOTTOM_ROW_TIGHTEN_Y = 10
local PROGRESS_SLOT_OFFSET_Y = 10
local LOWER_RIGHT_CONTROLS_OFFSET_X = -48

-- Ordinary DragonUI lays out 36-unit action buttons with a 7-unit gap, then
-- renders those bars at 0.9 scale. Apply the effective measurements
-- directly so the native parents, micro menu, and bags can remain unscaled.
local DRAGONUI_ACTION_BAR_SCALE = 0.9
local COMPACT_ACTION_BUTTON_SIZE = 36 * DRAGONUI_ACTION_BAR_SCALE
local COMPACT_ACTION_BUTTON_SPACING = 7 * DRAGONUI_ACTION_BAR_SCALE
local STOCK_MAIN_MENU_BAR_WIDTH = 1024
local STOCK_MAIN_ACTION_START_X = 8
local STOCK_ACTION_BUTTON_COUNT = 12
local COMPACT_ACTION_ROW_WIDTH =
    STOCK_ACTION_BUTTON_COUNT * COMPACT_ACTION_BUTTON_SIZE
    + (STOCK_ACTION_BUTTON_COUNT - 1) * COMPACT_ACTION_BUTTON_SPACING

-- Center the single regular gap between the two 12-button upper rows. The
-- result is +42.75 at DragonUI's effective 32.4 / 6.3 geometry. Apply this to
-- player-content anchors rather than MainMenuBar itself: Blizzard hardcodes
-- the root to x=0 during vehicle animations, while child offsets ride those
-- animations without a horizontal snap.
local BOTTOM_COMPLEX_OFFSET_X = STOCK_MAIN_MENU_BAR_WIDTH / 2
    - STOCK_MAIN_ACTION_START_X
    - COMPACT_ACTION_ROW_WIDTH
    - COMPACT_ACTION_BUTTON_SPACING / 2
local COMPACT_ADDITIONAL_BUTTON_SIZE = 31
local COMPACT_ADDITIONAL_BUTTON_SPACING = 6
local COMPACT_TOTEM_BUTTON_SIZE = 34
local COMPACT_TOTEM_BUTTON_SPACING = 4
local DRAGONUI_SIDE_BAR_SCALE = 0.9
local DRAGONUI_RIGHT_BAR_X = -5
local DRAGONUI_LEFT_BAR_X = -45
local DRAGONUI_SIDE_BAR_Y = -70
local DRAGONUI_SIDE_BUTTON_SIZE = 36
local DRAGONUI_SIDE_BUTTON_SPACING = 7
local LATENCY_LOW_THRESHOLD = 200
local LATENCY_MEDIUM_THRESHOLD = 300

local COMPACT_ACTION_ROW_HEIGHT_DELTA = 36 - COMPACT_ACTION_BUTTON_SIZE

-- These modules replace, reparent, resize, or otherwise manage Blizzard's
-- native controls.  Runtime overrides leave the user's saved module settings
-- untouched, so disabling this mode and reloading restores ordinary DragonUI.
local MODULE_OVERRIDES = {
    noop = false,
    mainbars = false,
    stance = false,
    petbar = false,
    multicast = false,
    vehicle = false,
    extrabar1 = false,
    micromenu = false,
    buttons = true,
}

local function TintChrome(texture)
    if not texture or not texture.SetVertexColor then return end
    -- Establish the native skin's own baseline first. The Dark Mode bridge
    -- records that baseline before applying its active preset, so a live Dark
    -- Mode disable restores .15 even for child textures created late.
    texture:SetVertexColor(DARK_R, DARK_G, DARK_B, 1)
    if addon.ApplyDarkModeChromeTexture and addon.IsDarkModeApplied
        and addon.IsDarkModeApplied() then
        addon.ApplyDarkModeChromeTexture(texture)
    end
end

function Layout:IsEnabled()
    if self.sessionEnabled ~= nil then
        return self.sessionEnabled
    end

    local profile = addon.db and addon.db.profile
    local config = profile and profile.blizzard_default_layout
    local enabled = config and config.enabled == true or false

    -- This setting requires a reload. Latch the first AceDB-backed value so a
    -- profile/toggle write cannot swap geometry ownership midway through play.
    if addon.db and type(addon.db.RegisterCallback) == "function" then
        self.sessionEnabled = enabled
    end
    return enabled
end

function Layout:GetModuleOverride(moduleName)
    if not self:IsEnabled() then
        return nil
    end
    return MODULE_OVERRIDES[moduleName]
end

function addon:GetModuleEnabledOverride(moduleName)
    return Layout:GetModuleOverride(moduleName)
end

function Layout:TintActionButton(button)
    if not self:IsEnabled() or not button then return end

    local name = button.GetName and button:GetName()
    local normal = name and (_G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"])
        or nil
    if not normal and button.GetNormalTexture then
        normal = button:GetNormalTexture()
    end

    TintChrome(normal)
    TintChrome(button.background)
end

-- ============================================================================
-- STOCK SHELL / PAGE-CONTROL SUPPRESSION
-- ============================================================================

local DECORATIVE_OBJECT_NAMES = {
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "MainMenuBarPerformanceBar",
    "MainMenuBarMaxLevelBar",
    "SlidingActionBarTexture0",
    "SlidingActionBarTexture1",
    "BonusActionBarTexture0",
    "BonusActionBarTexture1",
    "ShapeshiftBarLeft",
    "ShapeshiftBarMiddle",
    "ShapeshiftBarRight",
    "PossessBackground1",
    "PossessBackground2",
}

local PAGE_CONTROL_NAMES = {
    "ActionBarUpButton",
    "ActionBarDownButton",
    "MainMenuBarPageNumber",
}

local function HideDecorativeObject(object)
    if not object then return end
    if object.SetAlpha then object:SetAlpha(0) end
    local isTexture = object.GetObjectType and object:GetObjectType() == "Texture"
    local inCombat = InCombatLockdown and InCombatLockdown()
    if object.Hide and (isTexture or not inCombat) then
        object:Hide()
    end
end

local function NeutralizeHiddenMaxLevelClearance(bottomLeftPosition)
    if not bottomLeftPosition then
        local managedPositions = _G.UIPARENT_MANAGED_FRAME_POSITIONS
        bottomLeftPosition = managedPositions
            and managedPositions.MultiBarBottomLeft
    end
    if bottomLeftPosition then
        -- Blizzard normally lowers both managed multibars by five units while
        -- MainMenuBarMaxLevelBar is shown. This skin strips that bar, so make
        -- its layout contribution zero before hiding it. Otherwise its OnHide
        -- manager pass produces a visible five-unit hop just after /reload.
        bottomLeftPosition.maxLevel = 0
    end
end

local function HidePageControl(control)
    if not control then return end
    if control.SetAlpha then control:SetAlpha(0) end
    local inCombat = InCombatLockdown and InCombatLockdown()
    -- ActionBarUpButton/ActionBarDownButton can be protected through their
    -- native bar parent.  Mouse and visibility changes are established while
    -- out of combat; an in-combat Show only needs its alpha re-suppressed.
    if not inCombat and control.EnableMouse then control:EnableMouse(false) end
    if not inCombat and control.Hide then
        control:Hide()
    end
end

function Layout:HideStockChrome()
    if not self:IsEnabled() then return end

    NeutralizeHiddenMaxLevelClearance()
    for _, name in ipairs(DECORATIVE_OBJECT_NAMES) do
        HideDecorativeObject(_G[name])
    end
    for _, name in ipairs(PAGE_CONTROL_NAMES) do
        HidePageControl(_G[name])
    end
end

-- ============================================================================
-- NATIVE MICRO-MENU SKIN
-- ============================================================================

local MICRO_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\uimicromenu2x"
local MICRO_PVP_TEXTURE = "Interface\\AddOns\\DragonUI\\Textures\\Micromenu\\micropvp"

-- The colored DragonUI atlas is authored for a 32x40 button. Blizzard's
-- native WotLK hit boxes are substantially taller, so filling those roots
-- would stretch the atlas artwork. Only these child textures are sized; the
-- Blizzard buttons themselves remain untouched.
local MICRO_ART_WIDTH, MICRO_ART_HEIGHT = 32, 40
local MICRO_BACKGROUND_WIDTH, MICRO_BACKGROUND_HEIGHT = 32, 41
local CHARACTER_PORTRAIT_WIDTH, CHARACTER_PORTRAIT_HEIGHT = 18, 24

local function AnchorChildTexture(texture, button, width, height, x, y)
    if not texture or not button then return end
    texture:ClearAllPoints()
    texture:SetSize(width, height)
    texture:SetPoint("CENTER", button, "CENTER", x or 0, y or 0)
end

local function EnsureMicroArtAnchor(button)
    if not button then return nil end
    local anchor = button.__DragonUINativeArtAnchor
    if not anchor then
        -- An untextured child region gives every state layer one stable 32x40
        -- coordinate space without changing the protected Blizzard button.
        anchor = button:CreateTexture(nil, "BACKGROUND")
        button.__DragonUINativeArtAnchor = anchor
    end
    anchor:ClearAllPoints()
    anchor:SetSize(MICRO_ART_WIDTH, MICRO_ART_HEIGHT)
    anchor:SetPoint("BOTTOM", button, "BOTTOM", 0, 0)
    return anchor
end

local function AnchorMicroTexture(texture, button, width, height, x, y)
    local anchor = EnsureMicroArtAnchor(button)
    if not texture or not anchor then return end
    texture:ClearAllPoints()
    texture:SetSize(width, height)
    texture:SetPoint("CENTER", anchor, "CENTER", x or 0, y or 0)
end

local MICRO_ATLAS = {
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
    ["UI-HUD-MicroMenu-Shop-Up"] = {0.387695, 0.450195, 0.658203, 0.818359},

    ["UI-HUD-MicroMenu-Collections-Disabled"] = {0.0654297, 0.12793, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-Collections-Down"] = {0.0654297, 0.12793, 0.822266, 0.982422},
    ["UI-HUD-MicroMenu-Collections-Mouseover"] = {0.129883, 0.192383, 0.00195312, 0.162109},
    ["UI-HUD-MicroMenu-Collections-Up"] = {0.129883, 0.192383, 0.166016, 0.326172},

    -- Ascension-native micro buttons.  Keeping these entries unconditional is
    -- harmless on stock clients because their corresponding frames are nil.
    ["UI-HUD-MicroMenu-Challenges-Disabled"] = {0.000976562, 0.0634766, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-Challenges-Down"] = {0.000976562, 0.0634766, 0.822266, 0.982422},
    ["UI-HUD-MicroMenu-Challenges-Mouseover"] = {0.0654297, 0.12793, 0.00195312, 0.162109},
    ["UI-HUD-MicroMenu-Challenges-Up"] = {0.0654297, 0.12793, 0.166016, 0.326172},

    ["UI-HUD-MicroMenu-PathToAscension-Disabled"] = {0.0654297, 0.12793, 0.658203, 0.818359},
    ["UI-HUD-MicroMenu-PathToAscension-Down"] = {0.0654297, 0.12793, 0.822266, 0.982422},
    ["UI-HUD-MicroMenu-PathToAscension-Mouseover"] = {0.129883, 0.192383, 0.00195312, 0.162109},
    ["UI-HUD-MicroMenu-PathToAscension-Up"] = {0.129883, 0.192383, 0.166016, 0.326172},
}

local MICRO_BUTTON_ART = {
    SpellbookMicroButton = "UI-HUD-MicroMenu-SpellbookAbilities",
    TalentMicroButton = "UI-HUD-MicroMenu-SpecTalents",
    AchievementMicroButton = "UI-HUD-MicroMenu-Achievements",
    QuestLogMicroButton = "UI-HUD-MicroMenu-Questlog",
    SocialsMicroButton = "UI-HUD-MicroMenu-GuildCommunities",
    LFDMicroButton = "UI-HUD-MicroMenu-Groupfinder",
    LFGMicroButton = "UI-HUD-MicroMenu-Groupfinder",
    CollectionsMicroButton = "UI-HUD-MicroMenu-Collections",
    PathToAscensionMicroButton = "UI-HUD-MicroMenu-PathToAscension",
    ChallengesMicroButton = "UI-HUD-MicroMenu-Challenges",
    MainMenuMicroButton = "UI-HUD-MicroMenu-Shop",
    HelpMicroButton = "UI-HUD-MicroMenu-GameMenu",
}

local function SetTextureState(button, setterName, getterName, coords, isHighlight)
    if not button or not coords or not button[setterName] then return end

    button[setterName](button, MICRO_TEXTURE)
    local texture = button[getterName] and button[getterName](button)
    if not texture then return end

    texture:SetTexture(MICRO_TEXTURE)
    texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    AnchorMicroTexture(texture, button, MICRO_ART_WIDTH, MICRO_ART_HEIGHT)
    if isHighlight then
        texture:SetBlendMode("ADD")
        texture:SetAlpha(1)
    end
end

local function EnsureMicroBackground(button)
    if not button then return end

    local background = button.__DragonUINativeBackground
    if not background then
        background = button:CreateTexture(nil, "BACKGROUND")
        button.__DragonUINativeBackground = background
    end

    background:SetTexture(MICRO_TEXTURE)
    background:SetTexCoord(0.0654297, 0.12793, 0.330078, 0.490234)
    AnchorMicroTexture(background, button, MICRO_BACKGROUND_WIDTH,
        MICRO_BACKGROUND_HEIGHT, -1, 1)
    TintChrome(background)
    background:Show()
    return background
end

local function EnsureMicroPushedBackground(button)
    if not button then return end

    local background = button.__DragonUINativePushedBackground
    if not background then
        background = button:CreateTexture(nil, "BACKGROUND")
        button.__DragonUINativePushedBackground = background
    end

    background:SetTexture(MICRO_TEXTURE)
    background:SetTexCoord(0.0654297, 0.12793, 0.494141, 0.654297)
    local offX, offY = 0, 0
    if button.GetPushedTextOffset then
        offX, offY = button:GetPushedTextOffset()
    end
    AnchorMicroTexture(background, button, MICRO_BACKGROUND_WIDTH,
        MICRO_BACKGROUND_HEIGHT, -1 + (offX or 0), 1 + (offY or 0))
    TintChrome(background)
    return background
end

local function SetMicroBackgroundPushed(button, pushed)
    local normal = EnsureMicroBackground(button)
    local pushedBackground = EnsureMicroPushedBackground(button)
    if pushed then
        if normal then normal:Hide() end
        if pushedBackground then pushedBackground:Show() end
    else
        if normal then normal:Show() end
        if pushedBackground then pushedBackground:Hide() end
    end
end

local function SkinGenericMicroButton(button, atlasBase)
    if not button or not atlasBase then return end
    EnsureMicroBackground(button)
    SetTextureState(button, "SetNormalTexture", "GetNormalTexture", MICRO_ATLAS[atlasBase .. "-Up"])
    SetTextureState(button, "SetPushedTexture", "GetPushedTexture", MICRO_ATLAS[atlasBase .. "-Down"])
    SetTextureState(button, "SetDisabledTexture", "GetDisabledTexture", MICRO_ATLAS[atlasBase .. "-Disabled"])
    SetTextureState(button, "SetHighlightTexture", "GetHighlightTexture", MICRO_ATLAS[atlasBase .. "-Mouseover"], true)
end

local GENERIC_MICRO_TEXTURE_STATES = {
    {"GetNormalTexture", "-Up"},
    {"GetPushedTexture", "-Down"},
    {"GetDisabledTexture", "-Disabled"},
    {"GetHighlightTexture", "-Mouseover"},
}

-- MainMenuMicroButton's Blizzard OnUpdate can replace its textures. Its root
-- frame is already skinned, so the per-frame guard only repairs a region when
-- Blizzard actually replaces that region's texture path.
local function RefreshGenericMicroTexturesIfChanged(button, atlasBase)
    if not button or not atlasBase then return end
    local missingRegion = false

    for _, state in ipairs(GENERIC_MICRO_TEXTURE_STATES) do
        local getterName, suffix = state[1], state[2]
        local texture = button[getterName] and button[getterName](button)
        local coords = MICRO_ATLAS[atlasBase .. suffix]
        if not texture then
            missingRegion = true
        elseif coords and texture:GetTexture() ~= MICRO_TEXTURE then
            texture:SetTexture(MICRO_TEXTURE)
            texture:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
            AnchorMicroTexture(texture, button, MICRO_ART_WIDTH, MICRO_ART_HEIGHT)
        end
    end

    if missingRegion then
        SkinGenericMicroButton(button, atlasBase)
    end
end

local function IsCharacterMicroButtonActive(button)
    local characterVisible = _G.CharacterFrame and _G.CharacterFrame.IsVisible
        and _G.CharacterFrame:IsVisible()
    local paperDollVisible = _G.PaperDollFrame and _G.PaperDollFrame.IsVisible
        and _G.PaperDollFrame:IsVisible()
    return characterVisible or paperDollVisible or false
end

local function ApplyCharacterMicroButtonState(button, forcedPushed)
    if not button then return end
    local pushed = forcedPushed
    if pushed == nil then
        pushed = IsCharacterMicroButtonActive(button)
    end

    SetMicroBackgroundPushed(button, pushed)
    local portrait = _G.MicroButtonPortrait
    if portrait then
        portrait:SetAlpha(pushed and 0.7 or 1)
    end
end

local function SkinCharacterMicroButton(button, forcedPushed)
    if not button then return end
    EnsureMicroBackground(button)
    EnsureMicroPushedBackground(button)

    if button.SetNormalTexture then button:SetNormalTexture(nil) end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetDisabledTexture then button:SetDisabledTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture(nil) end

    local portrait = _G.MicroButtonPortrait
    if portrait then
        if SetPortraitTexture then SetPortraitTexture(portrait, "player") end
        AnchorMicroTexture(portrait, button, CHARACTER_PORTRAIT_WIDTH,
            CHARACTER_PORTRAIT_HEIGHT, 0, -0.5)
        portrait:Show()
    end

    if portrait and not button.__DragonUINativePortraitHighlight then
        local highlight = button:CreateTexture(nil, "OVERLAY")
        highlight:SetAllPoints(portrait)
        highlight:SetBlendMode("ADD")
        highlight:Hide()
        button.__DragonUINativePortraitHighlight = highlight

        button:HookScript("OnEnter", function(self)
            local texture = self.__DragonUINativePortraitHighlight
            if not texture or not Layout:IsEnabled() then return end
            if SetPortraitTexture then SetPortraitTexture(texture, "player") end
            if _G.MicroButtonPortrait then
                texture:SetTexCoord(_G.MicroButtonPortrait:GetTexCoord())
            end
            texture:Show()
        end)
        button:HookScript("OnLeave", function(self)
            if self.__DragonUINativePortraitHighlight then
                self.__DragonUINativePortraitHighlight:Hide()
            end
        end)
    end

    if not button.__DragonUINativeStateHooks then
        button.__DragonUINativeStateHooks = true
        button:HookScript("OnMouseDown", function(self)
            if Layout:IsEnabled() then
                ApplyCharacterMicroButtonState(self, true)
            end
        end)
        button:HookScript("OnMouseUp", function(self)
            if Layout:IsEnabled() then
                ApplyCharacterMicroButtonState(self)
            end
        end)
    end

    ApplyCharacterMicroButtonState(button, forcedPushed)
end

local PVP_ACTIVE_FRAME_NAMES = {
    "PVPFrame",
    "PVPParentFrame",
    "BattlefieldFrame",
    "HonorFrame",
}

local function IsPVPMicroButtonActive(button)
    for _, frameName in ipairs(PVP_ACTIVE_FRAME_NAMES) do
        local frame = _G[frameName]
        if frame and frame.IsVisible and frame:IsVisible() then
            return true
        end
    end
    return false
end

local function ApplyPVPMicroButtonState(button, forcedPushed)
    if not button then return end
    local pushed = forcedPushed
    if pushed == nil then
        pushed = IsPVPMicroButtonActive(button)
    end

    SetMicroBackgroundPushed(button, pushed)
    local icon = button.__DragonUINativePVPIcon
    if icon then
        local offX, offY = 0, 0
        if pushed and button.GetPushedTextOffset then
            offX, offY = button:GetPushedTextOffset()
        end
        AnchorMicroTexture(icon, button, MICRO_ART_WIDTH, MICRO_ART_HEIGHT,
            offX or 0, offY or 0)
        local enabled = not button.IsEnabled or button:IsEnabled()
        if enabled == 0 then enabled = false end
        icon:SetAlpha((not enabled and 0.35) or (pushed and 0.7) or 1)
    end
    local hover = button.__DragonUINativePVPHover
    if hover then
        local offX, offY = 0, 0
        if pushed and button.GetPushedTextOffset then
            offX, offY = button:GetPushedTextOffset()
        end
        AnchorMicroTexture(hover, button, MICRO_ART_WIDTH, MICRO_ART_HEIGHT,
            offX or 0, offY or 0)
    end
end

local function SkinPVPMicroButton(button, forcedPushed)
    if not button then return end
    EnsureMicroBackground(button)
    EnsureMicroPushedBackground(button)

    local faction = UnitFactionGroup and UnitFactionGroup("player")
    local coords = faction == "Horde"
        and {118 / 256, 236 / 256, 0, 151 / 256}
        or {0, 118 / 256, 0, 151 / 256}

    -- Blizzard changes PVPMicroButton's NormalTexture alpha internally. Keep
    -- the faction icon independent so those updates cannot hide our artwork.
    if button.SetNormalTexture then button:SetNormalTexture(nil) end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetDisabledTexture then button:SetDisabledTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture(nil) end

    local icon = button.__DragonUINativePVPIcon
    if not icon then
        icon = button:CreateTexture(nil, "ARTWORK")
        button.__DragonUINativePVPIcon = icon
    end
    icon:SetTexture(MICRO_PVP_TEXTURE)
    icon:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    AnchorMicroTexture(icon, button, MICRO_ART_WIDTH, MICRO_ART_HEIGHT)
    icon:Show()

    local hover = button.__DragonUINativePVPHover
    if not hover then
        hover = button:CreateTexture(nil, "OVERLAY")
        hover:SetBlendMode("ADD")
        hover:SetAlpha(0.6)
        hover:Hide()
        button.__DragonUINativePVPHover = hover

        button:HookScript("OnEnter", function(self)
            if Layout:IsEnabled() and self.__DragonUINativePVPHover then
                self.__DragonUINativePVPHover:Show()
            end
        end)
        button:HookScript("OnLeave", function(self)
            if self.__DragonUINativePVPHover then
                self.__DragonUINativePVPHover:Hide()
            end
        end)
    end
    hover:SetTexture(MICRO_PVP_TEXTURE)
    hover:SetTexCoord(coords[1], coords[2], coords[3], coords[4])
    AnchorMicroTexture(hover, button, MICRO_ART_WIDTH, MICRO_ART_HEIGHT)

    if not button.__DragonUINativePVPStateHooks then
        button.__DragonUINativePVPStateHooks = true
        button:HookScript("OnMouseDown", function(self)
            if Layout:IsEnabled() then
                ApplyPVPMicroButtonState(self, true)
            end
        end)
        button:HookScript("OnMouseUp", function(self)
            if Layout:IsEnabled() then
                ApplyPVPMicroButtonState(self)
            end
        end)
    end

    ApplyPVPMicroButtonState(button, forcedPushed)
end

local function UpdateNativeLatencyIndicator(bar)
    if not bar then return end

    local _, _, latency = GetNetStats()
    latency = latency or 0
    if latency > LATENCY_MEDIUM_THRESHOLD then
        bar:SetStatusBarColor(1, 0, 0)
    elseif latency > LATENCY_LOW_THRESHOLD then
        bar:SetStatusBarColor(1, 1, 0)
    else
        bar:SetStatusBarColor(0, 1, 0)
    end
end

local function EnsureNativeLatencyIndicator(button)
    if not button then return end

    local bar = button.__DragonUINativeLatencyBar
    local microConfig = addon.db and addon.db.profile and addon.db.profile.micromenu
    if microConfig and microConfig.show_latency_indicator == false then
        if bar then bar:Hide() end
        return
    end

    if not bar then
        bar = CreateFrame("StatusBar", nil, button)
        bar.updateElapsed = 0
        bar:SetScript("OnUpdate", function(self, elapsed)
            self.updateElapsed = (self.updateElapsed or 0) + elapsed
            if self.updateElapsed < 10 then return end
            self.updateElapsed = 0
            UpdateNativeLatencyIndicator(self)
        end)
        button.__DragonUINativeLatencyBar = bar
    end

    -- Match standard DragonUI's colored-mode geometry: this is a tall underlay
    -- one frame behind Help. The button artwork masks its body, leaving only
    -- the short colored foot visible beneath the button.
    bar:SetParent(button)
    bar:SetFrameStrata(button:GetFrameStrata())
    bar:SetFrameLevel(math.max(1, button:GetFrameLevel() - 1))
    bar:EnableMouse(false)
    bar:SetStatusBarTexture(addon._dir .. "ui-mainmenubar-performancebar")
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    bar:SetAlpha(1)
    bar:ClearAllPoints()
    bar:SetSize(22, 60)
    bar:SetPoint("BOTTOM", button, "BOTTOM", 1, -6.5)
    local texture = bar:GetStatusBarTexture()
    if texture then
        texture:SetBlendMode("ADD")
        texture:SetDrawLayer("OVERLAY")
    end
    UpdateNativeLatencyIndicator(bar)
    bar:Show()
end

function Layout:SkinMicroButtons()
    if not self:IsEnabled() then return end

    for buttonName, atlasBase in pairs(MICRO_BUTTON_ART) do
        SkinGenericMicroButton(_G[buttonName], atlasBase)
    end
    SkinCharacterMicroButton(_G.CharacterMicroButton)
    SkinPVPMicroButton(_G.PVPMicroButton)
    EnsureNativeLatencyIndicator(_G.HelpMicroButton)
end

-- ============================================================================
-- NATIVE BAG SKIN
-- ============================================================================

local BAG_SLOT_NAMES = {
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
}

local BACKPACK_ART_SIZE = 50
local BACKPACK_CUTOUT_SIZE = 51
local BAG_BORDER_SIZE = 34
local BAG_HIGHLIGHT_SIZE = 40
local BAG_SLOT_ICON_SIZE = 20.1
local KEYRING_ICON_SIZE = 26.1
local BAG_ICON_X, BAG_ICON_Y = -1.05, 1.05

local function ApplyAtlas(texture, atlas)
    if not texture then return end
    if texture.set_atlas then
        texture:set_atlas(atlas)
    end
end

local function AnchorTextureToButton(texture, button, inset)
    if not texture or not button then return end
    inset = inset or 0
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", button, "TOPLEFT", inset, -inset)
    texture:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -inset, inset)
end

local function SkinBackpackButton(button)
    if not button then return end

    if button.SetNormalTexture then button:SetNormalTexture(nil) end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.SetCheckedTexture then button:SetCheckedTexture("") end

    local icon = _G.MainMenuBarBackpackButtonIconTexture
        or _G[button:GetName() .. "IconTexture"]
    if icon then
        ApplyAtlas(icon, "bag-main-2x")
        AnchorChildTexture(icon, button, BACKPACK_ART_SIZE, BACKPACK_ART_SIZE)
        icon:Show()
    end

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        ApplyAtlas(highlight, "bag-main-highlight-2x")
        AnchorChildTexture(highlight, button, BACKPACK_ART_SIZE, BACKPACK_ART_SIZE)
        highlight:SetBlendMode("ADD")
    end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then
        ApplyAtlas(checked, "bag-main-highlight-2x")
        AnchorChildTexture(checked, button, BACKPACK_ART_SIZE, BACKPACK_ART_SIZE)
    end

    local cutout = button.__DragonUINativeDarkCutout
    if not cutout then
        cutout = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.__DragonUINativeDarkCutout = cutout
    end
    if button.__DragonUI_DarkCutout
        and button.__DragonUI_DarkCutout ~= cutout then
        button.__DragonUI_DarkCutout:Hide()
    end
    cutout:SetTexture(addon._dir .. "bagslotCutout")
    AnchorChildTexture(cutout, button, BACKPACK_CUTOUT_SIZE,
        BACKPACK_CUTOUT_SIZE, 0.1, 0.1)
    TintChrome(cutout)
    cutout:Show()
end

local function SkinSmallBagButton(button, borderAtlas)
    if not button then return end

    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.SetCheckedTexture then button:SetCheckedTexture("") end

    local icon = _G[button:GetName() .. "IconTexture"]
    if icon then
        AnchorChildTexture(icon, button, BAG_SLOT_ICON_SIZE, BAG_SLOT_ICON_SIZE,
            BAG_ICON_X, BAG_ICON_Y)
        if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        icon:Show()
    end

    local background = button.__DragonUINativeBackground
    if not background then
        background = button:CreateTexture(nil, "BACKGROUND")
        button.__DragonUINativeBackground = background
    end
    background:SetTexture(addon._dir .. "bagslots2x")
    background:SetTexCoord(295 / 512, 356 / 512, 64 / 128, 125 / 128)
    AnchorChildTexture(background, button, BAG_BORDER_SIZE, BAG_BORDER_SIZE)
    TintChrome(background)
    background:Show()

    local border = button.__DragonUINativeBorder
    if not border then
        border = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.__DragonUINativeBorder = border
    end
    if button.__DragonUI_DarkBorder
        and button.__DragonUI_DarkBorder ~= border then
        button.__DragonUI_DarkBorder:Hide()
    end
    ApplyAtlas(border, borderAtlas or "bag-border-2x")
    AnchorChildTexture(border, button, BAG_BORDER_SIZE, BAG_BORDER_SIZE)
    TintChrome(border)
    border:Show()

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        ApplyAtlas(highlight, "bag-border-highlight-2x")
        AnchorChildTexture(highlight, button, BAG_HIGHLIGHT_SIZE, BAG_HIGHLIGHT_SIZE)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.5)
    end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then
        ApplyAtlas(checked, "bag-border-highlight-2x")
        AnchorChildTexture(checked, button, BAG_HIGHLIGHT_SIZE, BAG_HIGHLIGHT_SIZE)
    end
end

local function SkinKeyRingButton(button)
    if not button then return end

    if button.SetNormalTexture then button:SetNormalTexture("") end
    if button.SetPushedTexture then button:SetPushedTexture(nil) end
    if button.SetHighlightTexture then button:SetHighlightTexture("") end
    if button.SetCheckedTexture then button:SetCheckedTexture("") end

    -- Unlike a normal bag slot, this atlas contains the key artwork as well as
    -- its gray ring. Keep it untinted and layer a separate dark border over it.
    local normal = button.GetNormalTexture and button:GetNormalTexture()
    if normal then
        ApplyAtlas(normal, "bag-reagent-border-2x")
        AnchorChildTexture(normal, button, BAG_BORDER_SIZE, BAG_BORDER_SIZE)
        normal:SetVertexColor(1, 1, 1, 1)
        normal:Show()
    end

    local icon = _G[button:GetName() .. "IconTexture"]
    if icon then
        AnchorChildTexture(icon, button, KEYRING_ICON_SIZE, KEYRING_ICON_SIZE,
            BAG_ICON_X, BAG_ICON_Y)
        if icon.SetTexCoord then icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
        icon:Show()
    end

    local border = button.__DragonUINativeBorder
    if not border then
        border = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.__DragonUINativeBorder = border
    end
    ApplyAtlas(border, "bag-border-2x")
    AnchorChildTexture(border, button, BAG_BORDER_SIZE, BAG_BORDER_SIZE)
    TintChrome(border)
    border:Show()

    local highlight = button.GetHighlightTexture and button:GetHighlightTexture()
    if highlight then
        ApplyAtlas(highlight, "bag-border-highlight-2x")
        AnchorChildTexture(highlight, button, BAG_HIGHLIGHT_SIZE, BAG_HIGHLIGHT_SIZE)
        highlight:SetBlendMode("ADD")
        highlight:SetAlpha(0.5)
    end
    local checked = button.GetCheckedTexture and button:GetCheckedTexture()
    if checked then
        ApplyAtlas(checked, "bag-border-highlight-2x")
        AnchorChildTexture(checked, button, BAG_HIGHLIGHT_SIZE, BAG_HIGHLIGHT_SIZE)
    end
end

function Layout:SkinBags()
    if not self:IsEnabled() then return end

    SkinBackpackButton(_G.MainMenuBarBackpackButton)
    for _, name in ipairs(BAG_SLOT_NAMES) do
        SkinSmallBagButton(_G[name], "bag-border-2x")
    end
    SkinKeyRingButton(_G.KeyRingButton)
end

-- ============================================================================
-- BLIZZARD-OWNED XP / REPUTATION SLOT
-- ============================================================================
-- Keep Blizzard's StatusBars, values, events, visibility, text, rested-XP
-- overlay, and max-level reputation handoff. Only their background/chrome and
-- the clearance needed by the raised lowest row are changed here.

local EXPERIENCE_BAR_TEXTURE = addon._dir .. "uiexperiencebar"
local EXPERIENCE_BACKGROUND_COORDS = {
    0.00088878125 / 2048, 570 / 2048, 20 / 64, 29 / 64,
}
local EXPERIENCE_BORDER_COORDS = {
    1 / 2048, 572 / 2048, 1 / 64, 18 / 64,
}

local XP_BORDER_NAMES = {
    "MainMenuXPBarTexture0",
    "MainMenuXPBarTexture1",
    "MainMenuXPBarTexture2",
    "MainMenuXPBarTexture3",
}
local REPUTATION_WATCH_BORDER_NAMES = {
    "ReputationWatchBarTexture0",
    "ReputationWatchBarTexture1",
    "ReputationWatchBarTexture2",
    "ReputationWatchBarTexture3",
}
local REPUTATION_XP_BORDER_NAMES = {
    "ReputationXPBarTexture0",
    "ReputationXPBarTexture1",
    "ReputationXPBarTexture2",
    "ReputationXPBarTexture3",
}

local PROGRESS_CLEARANCE_POSITION_NAMES = {
    "ShapeshiftBarFrame",
    "PossessBarFrame",
    "MultiCastActionBarFrame",
    "PETACTIONBAR_YPOS",
    "MULTICASTACTIONBAR_YPOS",
}

local BOTTOM_COMPLEX_X_POSITION_NAMES = {
    "ShapeshiftBarFrame",
    "PossessBarFrame",
    "MultiCastActionBarFrame",
}

local function GetCompactUpperTierOffset(positionName)
    -- Blizzard moves these tiers between a one-row and two-row stack as the
    -- two optional bottom multibars are toggled. Match only the visible height
    -- removed from that current stack instead of applying a fixed offset.
    local bottomLeft = _G.MultiBarBottomLeft
    local bottomRight = _G.MultiBarBottomRight
    local bottomLeftShown = bottomLeft and bottomLeft:IsShown()
    local bottomRightShown = bottomRight and bottomRight:IsShown()

    -- Stock stance/possess/multicast tiers depend on BottomLeft. Pet is the
    -- exception: in right-only layouts Blizzard can place it above the visible
    -- BottomRight row, so retain a second-row adjustment for its Y variable.
    local hasUpperActionRow = bottomLeftShown
    if positionName == "PETACTIONBAR_YPOS" and bottomRightShown then
        hasUpperActionRow = true
    end
    local rowCount = hasUpperActionRow and 2 or 1
    return -(COMPACT_ACTION_ROW_HEIGHT_DELTA * rowCount)
end

local function FindXPBackground()
    local bar = _G.MainMenuExpBar
    if not bar then return nil end
    if bar.__DragonUINativeBackground then
        return bar.__DragonUINativeBackground
    end

    for _, region in ipairs({bar:GetRegions()}) do
        if region.GetObjectType and region:GetObjectType() == "Texture"
            and region.GetDrawLayer and region:GetDrawLayer() == "BACKGROUND" then
            bar.__DragonUINativeBackground = region
            return region
        end
    end
end

local function SkinProgressBackground(texture, owner)
    if not texture or not owner then return end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", owner, "TOPLEFT", -1, 0)
    texture:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 2, 0)
    texture:SetTexture(EXPERIENCE_BAR_TEXTURE)
    texture:SetTexCoord(unpack(EXPERIENCE_BACKGROUND_COORDS))
    texture:SetAlpha(1)
    texture:Show()
end

local function SkinProgressBorder(texture, owner)
    if not texture or not owner then return end
    texture:ClearAllPoints()
    texture:SetPoint("TOPLEFT", owner, "TOPLEFT", -3, 2)
    texture:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", 3, -2)
    texture:SetDrawLayer("OVERLAY", 1)
    texture:SetTexture(EXPERIENCE_BAR_TEXTURE)
    texture:SetTexCoord(unpack(EXPERIENCE_BORDER_COORDS))
    texture:SetAlpha(1)
    TintChrome(texture)
end

local function SkinProgressBorderGroup(names, owner)
    SkinProgressBorder(_G[names[1]], owner)
    -- Blizzard still owns Show/Hide for each primary texture and therefore
    -- retains the choice between stacked-reputation and XP-slot chrome. The
    -- old three-piece continuations are merely made transparent.
    for index = 2, #names do
        local texture = _G[names[index]]
        if texture then texture:SetAlpha(0) end
    end
end

function Layout:SkinXPRepBars()
    if not self:IsEnabled() then return end

    local xpBar = _G.MainMenuExpBar
    if xpBar then
        SkinProgressBackground(FindXPBackground(), xpBar)
        SkinProgressBorderGroup(XP_BORDER_NAMES, xpBar)
    end

    local repStatusBar = _G.ReputationWatchStatusBar
    if repStatusBar then
        SkinProgressBackground(_G.ReputationWatchStatusBarBackground,
            repStatusBar)
        SkinProgressBorderGroup(REPUTATION_WATCH_BORDER_NAMES, repStatusBar)
        SkinProgressBorderGroup(REPUTATION_XP_BORDER_NAMES, repStatusBar)
    end
end

local function GetProgressSlotState()
    local xpBar = _G.MainMenuExpBar
    local repBar = _G.ReputationWatchBar
    local xpShown = xpBar and xpBar:IsShown() or false
    local repShown = repBar and repBar:IsShown() or false
    local stateKey = (xpShown and 1 or 0) + (repShown and 2 or 0)
    return xpShown, repShown, stateKey
end

local function IsProgressSlotOccupied()
    local xpShown, repShown = GetProgressSlotState()
    return xpShown or repShown
end

local function SetManagedYOffset(position, addonOffset)
    if not position then return false end
    if not position.__DragonUINativeYOffsetCaptured then
        position.__DragonUINativeYOffsetCaptured = true
        position.__DragonUINativeBaseYOffset = position.yOffset or 0
    end

    local target = position.__DragonUINativeBaseYOffset + addonOffset
    if position.yOffset == target then return false end
    position.yOffset = target
    return true
end

local function SetManagedXOffset(position, addonOffset)
    if not position then return false end
    if not position.__DragonUINativeXOffsetCaptured then
        position.__DragonUINativeXOffsetCaptured = true
        position.__DragonUINativeBaseXOffset = position.xOffset or 0
    end

    local target = position.__DragonUINativeBaseXOffset + addonOffset
    if position.xOffset ~= target then position.xOffset = target end
    return target
end

local function ApplyBottomComplexManagedX(managedPositions)
    if not managedPositions then return false end
    for _, name in ipairs(BOTTOM_COMPLEX_X_POSITION_NAMES) do
        if not managedPositions[name] then return false end
    end

    local multicastTarget
    for _, name in ipairs(BOTTOM_COMPLEX_X_POSITION_NAMES) do
        local target = SetManagedXOffset(managedPositions[name],
            BOTTOM_COMPLEX_OFFSET_X)
        if name == "MultiCastActionBarFrame" then
            multicastTarget = target
        end
    end

    -- Multicast's slide animation uses this global instead of the managed
    -- table. Give both writers the same captured target so the static and
    -- animated endpoints cannot diverge or accumulate repeated offsets.
    if not multicastTarget then return false end
    _G.MULTICASTACTIONBAR_XPOS = multicastTarget
    return true
end

local function AnchorNativeProgressSlot()
    local mainBar = _G.MainMenuBar
    local xpBar = _G.MainMenuExpBar
    if not mainBar or not xpBar then return false end

    -- The lowest action row occupies Blizzard's old XP slot. Move the
    -- functional slot with that row while leaving MainMenuBar's root
    -- (and its now-stable vehicle animation) completely unchanged.
    xpBar:ClearAllPoints()
    xpBar:SetPoint("TOP", mainBar, "TOP", BOTTOM_COMPLEX_OFFSET_X,
        PROGRESS_SLOT_OFFSET_Y)

    local repBar = _G.ReputationWatchBar
    if repBar and repBar:IsShown() then
        repBar:ClearAllPoints()
        if xpBar:IsShown() then
            -- Blizzard's stacked anchor is BOTTOM at -3; translate it by +10.
            repBar:SetPoint("BOTTOM", mainBar, "TOP", BOTTOM_COMPLEX_OFFSET_X,
                -3 + PROGRESS_SLOT_OFFSET_Y)
        else
            -- At max level (or with XP disabled), reputation takes XP's slot.
            repBar:SetPoint("TOP", mainBar, "TOP", BOTTOM_COMPLEX_OFFSET_X,
                PROGRESS_SLOT_OFFSET_Y)
        end
    end
    return true
end

function Layout:ApplyProgressSlotLayout(forceManager)
    if not self:IsEnabled() then return end
    if self.applyingProgressLayout then return end
    local mainBar = _G.MainMenuBar

    -- XP and reputation are plain display frames. Restore their translated
    -- child anchors even while the protected action-bar manager must wait;
    -- this preloads the correct X on mounted reloads and incoming player art.
    if not AnchorNativeProgressSlot() then
        self.progressLayoutPending = true
        return
    end

    if (InCombatLockdown and InCombatLockdown())
        or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (mainBar and mainBar.animating) then
        self.progressLayoutPending = true
        return
    end

    local managedPositions = _G.UIPARENT_MANAGED_FRAME_POSITIONS
    local managePositions = _G.UIParent_ManageFramePositions
    local bottomLeftPosition = managedPositions
        and managedPositions.MultiBarBottomLeft
    if not managedPositions or not bottomLeftPosition
        or type(managePositions) ~= "function" then
        self.progressLayoutPending = true
        return
    end

    local xpShown, repShown, stateKey = GetProgressSlotState()
    local occupied = xpShown or repShown
    local clearance = occupied and PROGRESS_SLOT_OFFSET_Y or 0
    local changed = SetManagedYOffset(bottomLeftPosition,
        -BOTTOM_ROW_TIGHTEN_Y + clearance)

    for _, name in ipairs(PROGRESS_CLEARANCE_POSITION_NAMES) do
        local upperTierOffset = GetCompactUpperTierOffset(name)
        if SetManagedYOffset(managedPositions[name],
            clearance + upperTierOffset) then
            changed = true
        end
    end

    NeutralizeHiddenMaxLevelClearance(bottomLeftPosition)
    self.progressLayoutOccupied = occupied
    local stateChanged = self.progressLayoutStateKey ~= stateKey
    self.progressLayoutStateKey = stateKey
    self.progressLayoutPending = nil
    if changed or stateChanged or forceManager then
        self.applyingProgressLayout = true
        managePositions()
        self.applyingProgressLayout = nil
    end
end

-- ============================================================================
-- MULTICAST / TOTEM ADDITIVE CHROME
-- ============================================================================
-- DragonUI intentionally avoids replacing multicast NormalTextures because
-- that can make the buttons invisible on 3.3.5a.  Additive child textures are
-- safe: the native action button and all of its state remain untouched.

local function SkinMulticastButton(button)
    if not button then return end

    local border = button.__DragonUINativeActionBorder
    if not border then
        border = button:CreateTexture(nil, "OVERLAY", nil, 7)
        button.__DragonUINativeActionBorder = border
    end
    border:SetTexture(addon.config.assets.normal)
    border:ClearAllPoints()
    border:SetPoint("TOPRIGHT", button, "TOPRIGHT", 2.2, 2.3)
    border:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", -2.2, -2.2)
    TintChrome(border)
    border:Show()

    local background = button.__DragonUINativeActionBackground
    if not background then
        background = button:CreateTexture(nil, "BACKGROUND")
        button.__DragonUINativeActionBackground = background
    end
    ApplyAtlas(background, "ui-hud-actionbar-iconframe-slot")
    AnchorTextureToButton(background, button, 0)
    TintChrome(background)
    local buttonsConfig = addon.db and addon.db.profile and addon.db.profile.buttons
    if buttonsConfig and buttonsConfig.only_actionbackground then
        background:Hide()
    else
        background:Show()
    end
end

function Layout:SkinMulticastButtons()
    if not self:IsEnabled() then return end
    -- Multicast action buttons are protected. Creating their child regions is
    -- deferred until PLAYER_REGEN_ENABLED when a server creates them in combat.
    if InCombatLockdown and InCombatLockdown() then
        self.multicastSkinPending = true
        return
    end

    local count = (NUM_MULTI_CAST_PAGES or 6) * (NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4)
    for index = 1, count do
        SkinMulticastButton(_G["MultiCastActionButton" .. index])
    end
    SkinMulticastButton(_G.MultiCastSummonSpellButton)
    SkinMulticastButton(_G.MultiCastRecallSpellButton)
    self.multicastSkinPending = nil
end

-- ============================================================================
-- DRAGONUI BUTTON SIZE + REGULARIZED GAPS
-- ============================================================================
-- Every point below is rebuilt from a fixed Blizzard anchor. This function is
-- intentionally idempotent and out-of-combat only: page, form, pet, multicast,
-- and vehicle updates may call it repeatedly without accumulating movement.

local function ArrangeButtonRow(prefix, count, size, spacing, firstAnchor)
    local previous
    for index = 1, count do
        local button = _G[prefix .. index]
        if button then
            button:SetSize(size, size)
            button:ClearAllPoints()
            if index == 1 then
                if firstAnchor and firstAnchor.relativeTo then
                    button:SetPoint(firstAnchor.point, firstAnchor.relativeTo,
                        firstAnchor.relativePoint, firstAnchor.x, firstAnchor.y)
                end
            elseif previous then
                button:SetPoint("LEFT", previous, "RIGHT", spacing, 0)
            end
            previous = button
        end
    end
    return previous
end

local function ArrangeLowerRightControls()
    local artFrame = _G.MainMenuBarArtFrame
    local firstMicroButton = _G.CharacterMicroButton
    local backpack = _G.MainMenuBarBackpackButton
    if not artFrame or not firstMicroButton or not backpack then return false end

    -- Move both native chains by the same fixed amount. Their internal Blizzard
    -- anchors remain intact, including the optional keyring, so every supported
    -- menu/bag state moves as one unit with ample action-row clearance.
    firstMicroButton:ClearAllPoints()
    firstMicroButton:SetPoint("BOTTOMLEFT", artFrame, "BOTTOMLEFT",
        552 + LOWER_RIGHT_CONTROLS_OFFSET_X, 2)
    backpack:ClearAllPoints()
    backpack:SetPoint("BOTTOMRIGHT", artFrame, "BOTTOMRIGHT",
        -6 + LOWER_RIGHT_CONTROLS_OFFSET_X, 2)
    return true
end

local function ArrangeMainAndBottomRows()
    local artFrame = _G.MainMenuBarArtFrame
    local bonusFrame = _G.BonusActionBarFrame
    local bottomLeft = _G.MultiBarBottomLeft
    local bottomRight = _G.MultiBarBottomRight
    if not artFrame or not bonusFrame or not bottomLeft or not bottomRight then
        return false
    end

    ArrangeButtonRow("ActionButton", NUM_ACTIONBAR_BUTTONS or 12,
        COMPACT_ACTION_BUTTON_SIZE, COMPACT_ACTION_BUTTON_SPACING, {
            point = "BOTTOMLEFT", relativeTo = artFrame,
            relativePoint = "BOTTOMLEFT", x = STOCK_MAIN_ACTION_START_X,
            y = 4,
        })
    ArrangeButtonRow("BonusActionButton", NUM_ACTIONBAR_BUTTONS or 12,
        COMPACT_ACTION_BUTTON_SIZE, COMPACT_ACTION_BUTTON_SPACING, {
            point = "BOTTOMLEFT", relativeTo = bonusFrame,
            relativePoint = "BOTTOMLEFT", x = 5 + BOTTOM_COMPLEX_OFFSET_X,
            y = 4 + BOTTOM_ROW_TIGHTEN_Y,
        })
    local leftLast = ArrangeButtonRow("MultiBarBottomLeftButton",
        NUM_ACTIONBAR_BUTTONS or 12, COMPACT_ACTION_BUTTON_SIZE,
        COMPACT_ACTION_BUTTON_SPACING, {
            point = "BOTTOMLEFT", relativeTo = bottomLeft,
            relativePoint = "BOTTOMLEFT", x = 0, y = 0,
        })

    -- Anchor the right row's first button directly after the left row's last
    -- one. This removes Blizzard's hidden two-unit frame slack plus its ten-unit
    -- inter-frame offset, making the seam identical to every internal gap.
    ArrangeButtonRow("MultiBarBottomRightButton",
        NUM_ACTIONBAR_BUTTONS or 12, COMPACT_ACTION_BUTTON_SIZE,
        COMPACT_ACTION_BUTTON_SPACING, {
            point = "LEFT", relativeTo = leftLast,
            relativePoint = "RIGHT", x = COMPACT_ACTION_BUTTON_SPACING, y = 0,
        })
    return leftLast ~= nil and ArrangeLowerRightControls()
end

local sideBarTarget

local function GetSideBarTarget()
    if not sideBarTarget then
        sideBarTarget = CreateFrame("Frame", nil, UIParent)
        sideBarTarget:SetSize(1, 1)
        sideBarTarget:EnableMouse(false)
    end
    sideBarTarget:ClearAllPoints()
    sideBarTarget:SetPoint("CENTER", UIParent, "RIGHT",
        DRAGONUI_RIGHT_BAR_X, DRAGONUI_SIDE_BAR_Y)
    return sideBarTarget
end

local function PrepareSideBarColumn(prefix, bar)
    if not bar then return nil end
    local first
    local previous
    for index = 1, (NUM_ACTIONBAR_BUTTONS or 12) do
        local button = _G[prefix .. index]
        if button then
            button:SetSize(DRAGONUI_SIDE_BUTTON_SIZE,
                DRAGONUI_SIDE_BUTTON_SIZE)
            button:ClearAllPoints()
            if previous then
                button:SetPoint("TOP", previous, "BOTTOM", 0,
                    -DRAGONUI_SIDE_BUTTON_SPACING)
            else
                -- Reset to the immutable XML baseline before measuring. This
                -- makes the final offset absolute instead of cumulative.
                button:SetPoint("TOPRIGHT", bar, "TOPRIGHT", 0, 0)
                first = button
            end
            previous = button
        end
    end
    return first, previous
end

local function SetDragonUISideBarLayout()
    local rightBar = _G.MultiBarRight
    local leftBar = _G.MultiBarLeft
    if not rightBar or not leftBar then return false end

    rightBar:SetScale(DRAGONUI_SIDE_BAR_SCALE)
    leftBar:SetScale(DRAGONUI_SIDE_BAR_SCALE)
    local rightFirst, rightLast = PrepareSideBarColumn(
        "MultiBarRightButton", rightBar)
    local leftFirst = PrepareSideBarColumn("MultiBarLeftButton", leftBar)
    local target = GetSideBarTarget()
    if not rightFirst or not rightLast or not leftFirst or not target then
        return false
    end

    -- Measure in physical screen units, then convert the desired movement back
    -- into the scaled button's local units. The target is standard DragonUI's
    -- default column center: UIParent RIGHT at x=-5, y=-70.
    local targetCenterX, targetCenterY = target:GetCenter()
    local rightEdge = rightFirst:GetRight()
    local rightTop = rightFirst:GetTop()
    local rightBottom = rightLast:GetBottom()
    local uiScale = UIParent:GetEffectiveScale()
    local targetScale = target:GetEffectiveScale()
    local rightScale = rightFirst:GetEffectiveScale()
    local lastScale = rightLast:GetEffectiveScale()
    local leftScale = leftFirst:GetEffectiveScale()
    if not targetCenterX or not targetCenterY or not rightEdge
        or not rightTop or not rightBottom
        or not uiScale or uiScale == 0
        or not targetScale or targetScale == 0
        or not rightScale or rightScale == 0
        or not lastScale or lastScale == 0
        or not leftScale or leftScale == 0 then
        return false
    end

    local targetY = targetCenterY * targetScale
    local currentY = (rightTop * rightScale
        + rightBottom * lastScale) / 2
    local offsetY = (targetY - currentY) / rightScale
    local offsetX
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        -- A mounted reload can leave the hidden parent at its XML x=-7 before
        -- Blizzard's return animation targets x=0. Prepare for that endpoint.
        offsetX = DRAGONUI_RIGHT_BAR_X * uiScale / rightScale
    else
        local targetX = targetCenterX * targetScale
        local currentX = rightEdge * rightScale
        offsetX = (targetX - currentX) / rightScale
    end

    rightFirst:ClearAllPoints()
    rightFirst:SetPoint("TOPRIGHT", rightBar, "TOPRIGHT",
        offsetX, offsetY)

    -- The left column follows the visible right column during Blizzard's
    -- horizontal vehicle animation. This produces the exact -45 right edge
    -- without adding a second constraint to either animated parent frame.
    local edgeDelta = DRAGONUI_LEFT_BAR_X - DRAGONUI_RIGHT_BAR_X
    local leftGap = (rightFirst:GetWidth() * rightScale
        + edgeDelta * uiScale) / leftScale
    leftFirst:ClearAllPoints()
    leftFirst:SetPoint("TOPRIGHT", rightFirst, "TOPLEFT", leftGap, 0)
    return true
end

function Layout:ApplySideBarLayout()
    if not self:IsEnabled() then return end
    local rightBar = _G.MultiBarRight
    local leftBar = _G.MultiBarLeft
    if (InCombatLockdown and InCombatLockdown())
        or (rightBar and rightBar.animating)
        or (leftBar and leftBar.animating) then
        self.sideBarLayoutPending = true
        return
    end

    -- This absolute child layout is safe to establish while mounted once the
    -- side bars are hidden. The parent points remain Blizzard-owned throughout
    -- player/vehicle animation and are only used as a measurement baseline.
    if not SetDragonUISideBarLayout() then
        self.sideBarLayoutPending = true
        return
    end
    self.sideBarLayoutPending = nil
end

local function ArrangeStanceButtons()
    local frame = _G.ShapeshiftBarFrame
    if not frame or not _G.ShapeshiftButton1 then return end
    local forms = GetNumShapeshiftForms and GetNumShapeshiftForms() or 0
    ArrangeButtonRow("ShapeshiftButton", NUM_SHAPESHIFT_SLOTS or 10,
        COMPACT_ADDITIONAL_BUTTON_SIZE,
        COMPACT_ADDITIONAL_BUTTON_SPACING, {
            point = "BOTTOMLEFT", relativeTo = frame,
            relativePoint = "BOTTOMLEFT", x = forms == 1 and 12 or 10, y = 3,
        })
end

local function ArrangePossessButtons()
    local frame = _G.PossessBarFrame
    if not frame or not _G.PossessButton1 then return end
    ArrangeButtonRow("PossessButton", NUM_POSSESS_SLOTS or 2,
        COMPACT_ADDITIONAL_BUTTON_SIZE,
        COMPACT_ADDITIONAL_BUTTON_SPACING, {
            point = "BOTTOMLEFT", relativeTo = frame,
            relativePoint = "BOTTOMLEFT", x = 10, y = 3,
        })
end

local function ArrangeMulticastButtons()
    local frame = _G.MultiCastActionBarFrame
    local summon = _G.MultiCastSummonSpellButton
    if not frame or not summon then return end

    summon:SetSize(COMPACT_TOTEM_BUTTON_SIZE, COMPACT_TOTEM_BUTTON_SIZE)
    summon:ClearAllPoints()
    summon:SetPoint("LEFT", frame, "LEFT", 0, 0)

    local slots = NUM_MULTI_CAST_BUTTONS_PER_PAGE or 4
    local pages = NUM_MULTI_CAST_PAGES or 6
    local previous = summon:IsShown() and summon or nil
    for slotIndex = 1, slots do
        local slot = _G["MultiCastSlotButton" .. slotIndex]
        if slot then
            slot:SetSize(COMPACT_TOTEM_BUTTON_SIZE, COMPACT_TOTEM_BUTTON_SIZE)
            slot:ClearAllPoints()
            if previous then
                slot:SetPoint("LEFT", previous, "RIGHT",
                    COMPACT_TOTEM_BUTTON_SPACING, 0)
            else
                -- Preserve Blizzard's no-summon fallback instead of leaving a
                -- hidden summon-sized hole at the start of the totem row.
                slot:SetPoint("LEFT", frame, "LEFT", 3, 0)
            end
            previous = slot

            for page = 1, pages do
                local actionIndex = (page - 1) * slots + slotIndex
                local action = _G["MultiCastActionButton" .. actionIndex]
                if action then
                    action:SetSize(COMPACT_TOTEM_BUTTON_SIZE,
                        COMPACT_TOTEM_BUTTON_SIZE)
                    action:ClearAllPoints()
                    action:SetPoint("CENTER", slot, "CENTER", 0, 0)
                end
            end
        end
    end

    local recall = _G.MultiCastRecallSpellButton
    local activeSlots = tonumber(frame.numActiveSlots) or slots
    activeSlots = math.max(1, math.min(slots, activeSlots))
    local lastSlot = _G["MultiCastSlotButton" .. activeSlots] or previous
    if recall and lastSlot then
        recall:SetSize(COMPACT_TOTEM_BUTTON_SIZE, COMPACT_TOTEM_BUTTON_SIZE)
        recall:ClearAllPoints()
        recall:SetPoint("LEFT", lastSlot, "RIGHT",
            COMPACT_TOTEM_BUTTON_SPACING, 0)
    end
end

local function ArrangePetButtons()
    local frame = _G.PetActionBarFrame
    if not frame or not _G.PetActionButton1 then return end
    ArrangeButtonRow("PetActionButton", NUM_PET_ACTION_SLOTS or 10,
        COMPACT_ADDITIONAL_BUTTON_SIZE,
        COMPACT_ADDITIONAL_BUTTON_SPACING, {
            point = "BOTTOMLEFT", relativeTo = frame,
            relativePoint = "BOTTOMLEFT", x = 36, y = 2,
        })
end

local function RefreshPetFrameHorizontalPosition()
    local frame = _G.PetActionBarFrame
    local updatePosition = _G.PetActionBar_UpdatePositionValues
    if not frame or type(updatePosition) ~= "function" then return end

    -- Stance geometry can change the screen-space value Blizzard uses for a
    -- side-by-side pet bar. Recompute after all of its possible dependencies
    -- have settled; our post-hook adds +42.75 only for stock's fixed-X states.
    updatePosition()
    if not frame:IsShown() then return end

    local point, relativeTo, relativePoint, _, currentY = frame:GetPoint(1)
    local targetX = tonumber(_G.PETACTIONBAR_XPOS)
    if point ~= "TOPLEFT" or relativeTo ~= _G.MainMenuBar
        or relativePoint ~= "BOTTOMLEFT" or not targetX then
        return
    end

    -- Preserve the current slide Y while correcting X. Blizzard's next pet
    -- OnUpdate continues from the same timer/mode using the refreshed global.
    frame:ClearAllPoints()
    frame:SetPoint(point, relativeTo, relativePoint, targetX, currentY or 0)
end

function Layout:ApplyCompactGeometry()
    if not self:IsEnabled() then return end
    self:ApplySideBarLayout()
    local mainBar = _G.MainMenuBar
    if (InCombatLockdown and InCombatLockdown())
        or (UnitHasVehicleUI and UnitHasVehicleUI("player"))
        or (mainBar and mainBar.animating) then
        self.compactGeometryPending = true
        return
    end

    if not ArrangeMainAndBottomRows() then
        self.compactGeometryPending = true
        return
    end
    ArrangeStanceButtons()
    ArrangePossessButtons()
    ArrangeMulticastButtons()
    RefreshPetFrameHorizontalPosition()
    ArrangePetButtons()

    self.compactGeometryApplied = true
    self.compactGeometryPending = nil
end

-- ============================================================================
-- STABLE WHOLE-COMPLEX LIFT + ROW TIGHTENING
-- ============================================================================

-- The root lift moves every player-art tier together. A second deterministic
-- transform creates the tighter lowest-row gap inside that lifted
-- complex. Every point below is a stock 3.3.5 anchor plus a fixed constant;
-- no live points are captured and no offset is ever accumulated.
local bottomRootWatcher = CreateFrame("Frame")
bottomRootWatcher:Hide()

function Layout:ApplyBottomRowTightening()
    if not self:IsEnabled() or not self.bottomRootReady
        or self.bottomGeometryApplied then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.bottomGeometryPending = true
        return
    end

    local bar = _G.MainMenuBar
    local artFrame = _G.MainMenuBarArtFrame
    local bonusFrame = _G.BonusActionBarFrame
    local bonusButton = _G.BonusActionButton1
    local managedPositions = _G.UIPARENT_MANAGED_FRAME_POSITIONS
    local bottomLeftPosition = managedPositions
        and managedPositions.MultiBarBottomLeft
    local managePositions = _G.UIParent_ManageFramePositions
    if not bar or not artFrame or not bonusFrame or not bonusButton
        or not bottomLeftPosition or type(managePositions) ~= "function" then
        self.bottomGeometryPending = true
        return
    end
    if not ApplyBottomComplexManagedX(managedPositions) then
        self.bottomGeometryPending = true
        return
    end

    -- Main action buttons, the player micro menu, and the bag chain all live
    -- under this stock two-point art container. Translate the container once
    -- instead of touching each protected child independently. Equal X offsets
    -- preserve its width and let the translated children ride Blizzard's
    -- animation-owned MainMenuBar root without a mount/dismount snap.
    artFrame:ClearAllPoints()
    artFrame:SetPoint("TOPLEFT", bar, "TOPLEFT", BOTTOM_COMPLEX_OFFSET_X,
        BOTTOM_ROW_TIGHTEN_Y)
    artFrame:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT",
        BOTTOM_COMPLEX_OFFSET_X, BOTTOM_ROW_TIGHTEN_Y)

    -- BonusActionBarFrame is MainMenuBar's sibling of the art container, so
    -- its first button receives the same fixed lift and player-content
    -- centering translation from its stock (5, 4).
    bonusButton:ClearAllPoints()
    bonusButton:SetPoint("BOTTOMLEFT", bonusFrame,
        "BOTTOMLEFT", 5 + BOTTOM_COMPLEX_OFFSET_X,
        4 + BOTTOM_ROW_TIGHTEN_Y)

    -- MultiBarBottomLeft is natively managed relative to ActionButton1. Its
    -- normal native-skin offset cancels the inner +10. A visible XP/rep slot
    -- needs that clearance back, and ApplyProgressSlotLayout also raises the
    -- other managed upper tiers by the same amount.
    NeutralizeHiddenMaxLevelClearance(bottomLeftPosition)
    local progressClearance = IsProgressSlotOccupied()
        and PROGRESS_SLOT_OFFSET_Y or 0
    SetManagedYOffset(bottomLeftPosition,
        -BOTTOM_ROW_TIGHTEN_Y + progressClearance)
    managePositions()

    self.bottomGeometryApplied = true
    self.bottomGeometryPending = nil
end

function Layout:WatchBottomRootReturn()
    if self.bottomRootWatching then return end
    self.bottomRootPending = true
    self.bottomRootWatching = true
    bottomRootWatcher:Show()
end

function Layout:CancelBottomRootReturn()
    self.bottomRootWatching = nil
    self.bottomRootPending = nil
    bottomRootWatcher:Hide()
end

function Layout:ApplyBottomRootOffset()
    if not self:IsEnabled() or not self.bottomRootReady then return end

    local bar = _G.MainMenuBar
    if not bar then return end

    -- VehicleMenuBar owns its own art and micro-button placement. Let the
    -- outgoing player bar animate normally and restore the lift on return.
    if UnitHasVehicleUI and UnitHasVehicleUI("player") then
        self:CancelBottomRootReturn()
        return
    end

    if bar.animating then
        self.bottomRootPending = true
        self:WatchBottomRootReturn()
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.bottomRootPending = true
        return
    end

    -- Keep Blizzard's animation-owned horizontal root at zero. The centering
    -- translation lives on the player-content anchors so mount and
    -- dismount animations cannot introduce a horizontal jump.
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, BOTTOM_COMPLEX_OFFSET_Y)
    self.bottomRootPending = nil
end

bottomRootWatcher:SetScript("OnUpdate", function(self)
    if not Layout:IsEnabled() then
        Layout.bottomRootWatching = nil
        self:Hide()
        return
    end

    local bar = _G.MainMenuBar
    if not bar then
        Layout.bottomRootWatching = nil
        self:Hide()
        return
    end
    if bar.animating then return end

    Layout.bottomRootWatching = nil
    self:Hide()
    Layout:ApplyBottomRootOffset()
    Layout:ApplyCompactGeometry()
    if Layout.progressLayoutPending then
        Layout:ApplyProgressSlotLayout(true)
    end
end)

-- ============================================================================
-- LIFECYCLE / REASSERTION HOOKS
-- ============================================================================

function Layout:ApplyVisuals()
    if not self:IsEnabled() then return end
    self:HideStockChrome()
    self:SkinMicroButtons()
    self:SkinBags()
    self:ApplyCompactGeometry()
    self:SkinXPRepBars()
    self:ApplyProgressSlotLayout()
    self:SkinMulticastButtons()
end

local function RefreshAdditionalActionSkins()
    if addon.RefreshNativeAdditionalButtonSkins then
        addon.RefreshNativeAdditionalButtonSkins()
    end
end

local function PetUsesDerivedX()
    if _G.PetActionBarFrame_IsAboveShapeshift
        and _G.PetActionBarFrame_IsAboveShapeshift(true) then
        return false
    end

    local leaveButton = _G.MainMenuBarVehicleLeaveButton
    if leaveButton and leaveButton:IsShown() then return true end

    local forms = _G.GetNumShapeshiftForms
        and _G.GetNumShapeshiftForms() or 0
    if _G.ShapeshiftBarFrame and forms > 0 then return true end

    return _G.MultiCastActionBarFrame and _G.HasMultiCastActionBar
        and _G.HasMultiCastActionBar() or false
end

local function InstallHooks()
    if Layout.hooksInstalled then return end
    Layout.hooksInstalled = true

    local artFunctions = {
        "MainMenuBar_UpdateArt",
        "MainMenuBar_ToPlayerArt",
        "MainMenuBar_ToVehicleArt",
    }
    for _, functionName in ipairs(artFunctions) do
        if type(_G[functionName]) == "function" then
            local hookedFunctionName = functionName
            hooksecurefunc(functionName, function()
                if Layout:IsEnabled() then
                    Layout:HideStockChrome()
                    RefreshAdditionalActionSkins()
                    if hookedFunctionName == "MainMenuBar_ToPlayerArt" then
                        -- Stock has just returned the micro/bag chains to the
                        -- player art and rewritten CharacterMicroButton's
                        -- anchor. Restore only those child anchors now so they
                        -- ride the incoming parent animation without a snap.
                        -- The full geometry pass remains deferred until the
                        -- animated parent has reached its endpoint.
                        if InCombatLockdown and InCombatLockdown() then
                            Layout.compactGeometryPending = true
                        elseif not ArrangeLowerRightControls() then
                            Layout.compactGeometryPending = true
                        end
                        Layout:WatchBottomRootReturn()
                    elseif hookedFunctionName == "MainMenuBar_ToVehicleArt" then
                        Layout:CancelBottomRootReturn()
                        Layout:ApplySideBarLayout()
                    end
                end
            end)
        end
    end

    -- Blizzard's right-bar player animation owns the parent point through its
    -- final frame. Re-measure the child-column offset immediately afterward.
    if type(_G.MainMenuBar_UnlockAB) == "function" then
        hooksecurefunc("MainMenuBar_UnlockAB", function()
            if Layout:IsEnabled() then Layout:ApplySideBarLayout() end
        end)
    end

    -- Reputation, action-bar visibility, and other stock layout changes can
    -- alter MultiBarRight's managed baseline. The child layout is absolute, so
    -- a post-hook safely recomputes it without calling the manager recursively.
    if type(_G.UIParent_ManageFramePositions) == "function" then
        hooksecurefunc("UIParent_ManageFramePositions", function()
            if Layout:IsEnabled() then Layout:ApplySideBarLayout() end
        end)
    end

    for _, name in ipairs(PAGE_CONTROL_NAMES) do
        local control = _G[name]
        if control and control.HookScript and not control.__DragonUINativeHideHook then
            control.__DragonUINativeHideHook = true
            control:HookScript("OnShow", function(self)
                if Layout:IsEnabled() then HidePageControl(self) end
            end)
        end
    end

    if type(_G.UpdateMicroButtons) == "function" then
        hooksecurefunc("UpdateMicroButtons", function()
            if Layout:IsEnabled() then
                Layout:SkinMicroButtons()
                Layout:ApplyCompactGeometry()
            end
        end)
    end

    -- Stock recomputes PETACTIONBAR_XPOS from scratch before every use. Its
    -- fixed branches still start at 36 and need the common translation; its
    -- stance/leave/multicast branches already derive X from translated frames.
    if type(_G.PetActionBar_UpdatePositionValues) == "function" then
        hooksecurefunc("PetActionBar_UpdatePositionValues", function()
            if Layout:IsEnabled() and not PetUsesDerivedX() then
                _G.PETACTIONBAR_XPOS =
                    (tonumber(_G.PETACTIONBAR_XPOS) or 36)
                    + BOTTOM_COMPLEX_OFFSET_X
            end
        end)
    end

    -- Blizzard retains all XP/reputation state ownership. These post-hooks
    -- only restore our atlas chrome and translated slot after a stock update.
    if type(_G.MainMenuExpBar_Update) == "function" then
        hooksecurefunc("MainMenuExpBar_Update", function()
            if Layout:IsEnabled() then
                Layout:SkinXPRepBars()
                Layout:ApplyProgressSlotLayout()
            end
        end)
    end
    if type(_G.ReputationWatchBar_Update) == "function" then
        hooksecurefunc("ReputationWatchBar_Update", function()
            if Layout:IsEnabled() then
                -- Unwatching at max level makes Blizzard show this decorative
                -- strip again; suppress it after Blizzard finishes the handoff.
                Layout:HideStockChrome()
                Layout:SkinXPRepBars()
                Layout:ApplyProgressSlotLayout()
            end
        end)
    end

    -- Blizzard can refresh pet buttons through control/farsight and unit-state
    -- paths that do not emit PET_BAR_UPDATE. Reapply only the existing grid
    -- option's alpha after every native refresh so it cannot be reset later.
    if type(_G.PetActionBar_Update) == "function" then
        hooksecurefunc("PetActionBar_Update", function()
            if Layout:IsEnabled() then
                Layout:ApplyCompactGeometry()
                if addon.RefreshPetbarGrid then
                    addon.RefreshPetbarGrid()
                end
            end
        end)
    end

    -- ShapeshiftBar_Update rewrites the first stance-button anchor, and the
    -- multicast update family rebuilds its summon/slot/recall chain. Restore
    -- compact geometry only after Blizzard has completed each native update.
    if type(_G.ShapeshiftBar_Update) == "function" then
        hooksecurefunc("ShapeshiftBar_Update", function()
            if Layout:IsEnabled() then Layout:ApplyCompactGeometry() end
        end)
    end
    if type(_G.MultiActionBar_Update) == "function" then
        hooksecurefunc("MultiActionBar_Update", function()
            if Layout:IsEnabled() then
                -- The 3.3.5 action-bar checkboxes update saved globals rather
                -- than CVars. Recompute only the managed vertical offsets after
                -- Blizzard has changed BottomLeft/BottomRight visibility.
                Layout:ApplyProgressSlotLayout(true)
            end
        end)
    end
    local multicastUpdateFunctions = {
        "MultiCastActionBarFrame_Update",
        "MultiCastSummonSpellButton_Update",
        "MultiCastRecallSpellButton_Update",
    }
    for _, functionName in ipairs(multicastUpdateFunctions) do
        if type(_G[functionName]) == "function" then
            hooksecurefunc(functionName, function()
                if Layout:IsEnabled() then Layout:ApplyCompactGeometry() end
            end)
        end
    end

    if type(_G.CharacterMicroButton_SetNormal) == "function" then
        hooksecurefunc("CharacterMicroButton_SetNormal", function()
            if Layout:IsEnabled() then SkinCharacterMicroButton(_G.CharacterMicroButton) end
        end)
    end
    if type(_G.CharacterMicroButton_SetPushed) == "function" then
        hooksecurefunc("CharacterMicroButton_SetPushed", function()
            if Layout:IsEnabled() then SkinCharacterMicroButton(_G.CharacterMicroButton, true) end
        end)
    end

    local mainMenuButton = _G.MainMenuMicroButton
    if mainMenuButton and mainMenuButton.HookScript and not mainMenuButton.__DragonUINativeUpdateHook then
        mainMenuButton.__DragonUINativeUpdateHook = true
        mainMenuButton:HookScript("OnUpdate", function(self)
            if Layout:IsEnabled() then
                RefreshGenericMicroTexturesIfChanged(self, MICRO_BUTTON_ART.MainMenuMicroButton)
            end
        end)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
eventFrame:RegisterEvent("PET_BAR_UPDATE")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
eventFrame:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
eventFrame:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
eventFrame:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
eventFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
eventFrame:RegisterEvent("UNIT_EXITED_VEHICLE")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= "DragonUI" then return end
    if not Layout:IsEnabled() then return end
    if (event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE")
        and arg1 ~= "player" then
        return
    end

    InstallHooks()

    if event == "DISPLAY_SIZE_CHANGED" then
        Layout:ApplySideBarLayout()
        return
    end

    -- MainMenuBar's exact player anchor is safe to establish after login.
    if event == "PLAYER_LOGIN" then
        Layout.bottomRootReady = true
    end
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Layout:ApplyBottomRowTightening()
    end

    -- BAG_UPDATE can fire for every ammo use. Keep that hot path limited to
    -- the five bag controls instead of restyling the whole bottom UI.
    if event == "BAG_UPDATE" or event == "PLAYER_EQUIPMENT_CHANGED" then
        Layout:SkinBags()
        return
    end

    if event == "PET_BAR_UPDATE" or event == "UPDATE_SHAPESHIFT_FORM"
        or event == "UPDATE_SHAPESHIFT_FORMS" then
        Layout:ApplyCompactGeometry()
        Layout:HideStockChrome()
        RefreshAdditionalActionSkins()
        return
    end

    if event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
        Layout:ApplyCompactGeometry()
        Layout:HideStockChrome()
        RefreshAdditionalActionSkins()
        return
    end

    Layout:ApplyVisuals()
    RefreshAdditionalActionSkins()

    if event == "PLAYER_REGEN_ENABLED" then
        if Layout.bottomGeometryPending then
            Layout:ApplyBottomRowTightening()
        end
        if Layout.bottomRootPending then
            Layout:ApplyBottomRootOffset()
        end
        if Layout.progressLayoutPending then
            Layout:ApplyProgressSlotLayout(true)
        end
        if Layout.compactGeometryPending then
            Layout:ApplyCompactGeometry()
        end
        if Layout.sideBarLayoutPending then
            Layout:ApplySideBarLayout()
        end
    end

    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD"
        or event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if event == "UNIT_ENTERED_VEHICLE"
            and UnitHasVehicleUI and UnitHasVehicleUI("player") then
            Layout:CancelBottomRootReturn()
        elseif event == "UNIT_EXITED_VEHICLE" then
            -- MainMenuBar's incoming player animation has not necessarily
            -- started yet. Its ToPlayerArt hook starts the watcher at the
            -- correct moment; the delayed call below remains a fallback.
            Layout.bottomRootPending = true
        else
            Layout:ApplyBottomRootOffset()
        end
        addon:After(0.1, function()
            if not Layout:IsEnabled() then return end
            if not Layout.bottomGeometryApplied then
                Layout:ApplyBottomRowTightening()
            end
            Layout:ApplyCompactGeometry()
            Layout:ApplyVisuals()
            RefreshAdditionalActionSkins()
        end)
        addon:After(0.35, function()
            if Layout:IsEnabled() then
                Layout:ApplySideBarLayout()
                Layout:ApplyBottomRootOffset()
            end
        end)
    end
end)
