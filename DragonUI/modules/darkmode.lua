local addon = select(2, ...)

-- ============================================================================
-- DARK MODE MODULE FOR DRAGONUI
-- Surgical darkening of UI chrome: ONLY borders, backgrounds, and frame art.
-- Never darkens ability icons, portraits, or interactive content.
-- Supports 3 intensity presets: Light, Medium, Dark.
-- ============================================================================

-- Module state tracking
local DarkModeModule = {
    initialized = false,
    applied = false,
    originalStates = {},
    registeredEvents = {},
    hooks = {},
    frames = {},
    darkenedTextures = {} -- Track all darkened textures for clean restore
}

-- Register with ModuleRegistry (if available)
if addon.RegisterModule then
    addon:RegisterModule("darkmode", DarkModeModule,
        addon.L["Dark Mode"],
        addon.L["Darken UI borders and chrome"])
end

-- ============================================================================
-- CONFIGURATION FUNCTIONS
-- ============================================================================

local function GetModuleConfig()
    return addon:GetModuleConfig("darkmode")
end

local function IsModuleEnabled()
    return addon:IsModuleEnabled("darkmode")
end

-- ============================================================================
-- DARK MODE INTENSITY PRESETS
-- ============================================================================

local INTENSITY_PRESETS = {
    [1] = 0.50, -- Light: subtle darkening
    [2] = 0.30, -- Medium: clearly darker
    [3] = 0.15, -- Dark: very dark
}

-- Code-only tuning for Target/Focus name background darkening.
-- 0.00 = no darkening, 1.00 = full unit frame dark tint.
local TARGET_FOCUS_NAME_BG_DARKEN_FACTOR = 0.5

local function IsTargetFocusNameBackgroundTexture(region)
    if not region then return false end
    return region == _G["TargetFrameNameBackground"]
        or region == _G["FocusFrameNameBackground"]
end

-- Tint tables are rebuilt in place: values depend only on config, so aliasing between callers is safe.
local tintCache = { 1, 1, 1 }
local ufTintCache = { 1, 1, 1 }
local nameBgTintCache = { 1, 1, 1 }
local auraTintCache = { 1, 1, 1 }

local function GetTargetFocusNameBackgroundTint(ufTint)
    local factor = TARGET_FOCUS_NAME_BG_DARKEN_FACTOR or 0
    if factor <= 0 then
        nameBgTintCache[1], nameBgTintCache[2], nameBgTintCache[3] = 1, 1, 1
    elseif factor >= 1 then
        nameBgTintCache[1], nameBgTintCache[2], nameBgTintCache[3] = ufTint[1], ufTint[2], ufTint[3]
    else
        -- Blend from neutral white to UF tint using the configured factor.
        nameBgTintCache[1] = 1 - ((1 - ufTint[1]) * factor)
        nameBgTintCache[2] = 1 - ((1 - ufTint[2]) * factor)
        nameBgTintCache[3] = 1 - ((1 - ufTint[3]) * factor)
    end
    return nameBgTintCache
end

local function GetTintValues()
    local config = GetModuleConfig()
    if config and config.use_custom_color and config.custom_color then
        local c = config.custom_color
        tintCache[1], tintCache[2], tintCache[3] = c.r or 0.15, c.g or 0.15, c.b or 0.15
        return tintCache
    end
    local preset = config and config.intensity_preset or 3
    local intensity = INTENSITY_PRESETS[preset] or INTENSITY_PRESETS[3]
    tintCache[1], tintCache[2], tintCache[3] = intensity, intensity, intensity
    return tintCache
end

-- Unit frames need to be noticeably darker than other UI chrome
-- due to their color composition (gold borders on dark backgrounds)
local function GetUFTintValues()
    local config = GetModuleConfig()
    if config and config.use_custom_color and config.custom_color then
        local c = config.custom_color
        -- UF borders get 60% of the custom color (darker)
        ufTintCache[1] = (c.r or 0.15) * 0.6
        ufTintCache[2] = (c.g or 0.15) * 0.6
        ufTintCache[3] = (c.b or 0.15) * 0.6
        return ufTintCache
    end
    local preset = config and config.intensity_preset or 3
    local intensity = INTENSITY_PRESETS[preset] or INTENSITY_PRESETS[3]
    -- UF borders get 60% of the normal intensity (darker)
    local ufIntensity = intensity * 0.6
    ufTintCache[1], ufTintCache[2], ufTintCache[3] = ufIntensity, ufIntensity, ufIntensity
    return ufTintCache
end

-- ============================================================================
-- CORE TEXTURE HELPERS
-- ============================================================================

local abs = math.abs
local TINT_EPSILON = 0.01

local function DarkenTexture(texture, tint)
    if not texture then return end
    local pr, pg, pb, pa = texture:GetVertexColor()
    -- Sweeps re-apply a static tint at high frequency; skip the C calls when it is already in place.
    if pr and DarkModeModule.darkenedTextures[texture]
        and abs(pr - tint[1]) < TINT_EPSILON
        and abs(pg - tint[2]) < TINT_EPSILON
        and abs(pb - tint[3]) < TINT_EPSILON then
        return
    end
    if not texture.__DragonUI_OrigColor then
        texture.__DragonUI_OrigColor = { pr, pg, pb, pa }
    end
    -- SetVertexColor(r,g,b) resets alpha to 1 and undoes hide_main_bar_background on gryphons.
    local keepAlpha = texture.GetAlpha and texture:GetAlpha() or 1
    texture.__DragonUI_SettingDark = true
    texture:SetVertexColor(tint[1], tint[2], tint[3], pa)
    texture.__DragonUI_SettingDark = nil
    if texture.SetAlpha then
        texture:SetAlpha(keepAlpha)
    end
    DarkModeModule.darkenedTextures[texture] = true
end

local function RestoreTexture(texture)
    if not texture then return end
    if texture.__DragonUI_OrigColor then
        local c = texture.__DragonUI_OrigColor
        local keepAlpha = texture.GetAlpha and texture:GetAlpha() or 1
        texture.__DragonUI_SettingDark = true
        texture:SetVertexColor(c[1], c[2], c[3], c[4] or 1)
        texture.__DragonUI_SettingDark = nil
        if texture.SetAlpha then
            texture:SetAlpha(keepAlpha)
        end
        texture.__DragonUI_OrigColor = nil
    end
    DarkModeModule.darkenedTextures[texture] = nil
end

-- Darken a single named global texture or frame-as-texture (like gryphons)
local function DarkenGlobal(name, tint)
    local obj = _G[name]
    if not obj then return end
    if obj.GetObjectType and obj:GetObjectType() == "Texture" then
        DarkenTexture(obj, tint)
    end
end

-- ============================================================================
-- SURGICAL DARKENING FUNCTIONS
-- Each function targets ONLY the border/chrome textures of a specific UI area.
-- ============================================================================

-- -----------------------------------------------------------------------
-- ACTION BAR BUTTONS: darken NormalTexture (border frame) and background,
-- but NEVER the Icon (ability texture)
-- -----------------------------------------------------------------------
-- Flat [buttonName, normalTextureName] pairs, built once: the sweep runs far too often to rebuild strings.
local ACTION_BUTTON_NAMES = {}
do
    local prefixes = {
        "ActionButton",
        "MultiBarBottomLeftButton",
        "MultiBarBottomRightButton",
        "MultiBarRightButton",
        "MultiBarLeftButton",
        "BonusActionButton",
        "DragonUI_ExtraBarButton",
    }
    local n = 0
    for _, prefix in ipairs(prefixes) do
        for i = 1, 12 do
            ACTION_BUTTON_NAMES[n + 1] = prefix .. i
            ACTION_BUTTON_NAMES[n + 2] = prefix .. i .. "NormalTexture"
            n = n + 2
        end
    end
end

local function DarkenActionButtonBorders(tint)
    for n = 1, #ACTION_BUTTON_NAMES, 2 do
        local button = _G[ACTION_BUTTON_NAMES[n]]
        if button then
            -- Darken NormalTexture (the border frame around the icon)
            local normal = _G[ACTION_BUTTON_NAMES[n + 1]] or (button.GetNormalTexture and button:GetNormalTexture())
            if normal and normal.GetObjectType and normal:GetObjectType() == "Texture" then
                DarkenTexture(normal, tint)
            end
            -- Darken background slot texture (created by DragonUI buttons module)
            if button.background and button.background.GetObjectType and button.background:GetObjectType() == "Texture" then
                DarkenTexture(button.background, tint)
            end
            -- DO NOT touch the "Icon" texture — that's the ability icon
        end
    end
end

-- -----------------------------------------------------------------------
-- STANCE / SHAPESHIFT BUTTONS: darken only NormalTexture (border),
-- NOT the Icon (ability texture)
-- -----------------------------------------------------------------------
local function DarkenStanceButtonBorders(tint)
    for i = 1, 10 do
        local button = _G["ShapeshiftButton" .. i]
        if button then
            local normal = _G["ShapeshiftButton" .. i .. "NormalTexture"] or (button.GetNormalTexture and button:GetNormalTexture())
            if normal and normal.GetObjectType and normal:GetObjectType() == "Texture" then
                DarkenTexture(normal, tint)
            end
            if button.background and button.background:GetObjectType() == "Texture" then
                DarkenTexture(button.background, tint)
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- PET BAR BUTTONS: darken only NormalTexture (border), NOT the Icon
-- -----------------------------------------------------------------------
local function DarkenPetButtonBorders(tint)
    for i = 1, 10 do
        local button = _G["PetActionButton" .. i]
        if button then
            local normal = _G["PetActionButton" .. i .. "NormalTexture2"] or _G["PetActionButton" .. i .. "NormalTexture"]
                           or (button.GetNormalTexture and button:GetNormalTexture())
            if normal and normal.GetObjectType and normal:GetObjectType() == "Texture" then
                DarkenTexture(normal, tint)
            end
            if button.background and button.background:GetObjectType() == "Texture" then
                DarkenTexture(button.background, tint)
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- XP / REP BAR BORDERS ONLY: named border textures for RetailUI,
-- .Border overlay for DragonflightUI. Never touches the fill bar.
-- -----------------------------------------------------------------------
local function DarkenXPRepBorders(tint)
    -- RetailUI: ONLY the 3 border textures restored by ApplyRetailUIExpRepBarStyling.
    -- Texture1-3 are cleared by noop and never restored — skip them entirely.
    local borderTexNames = {
        "MainMenuXPBarTexture0",
        "ReputationXPBarTexture0",
        "ReputationWatchBarTexture0",
    }
    for _, texName in ipairs(borderTexNames) do
        local tex = _G[texName]
        if tex and tex.GetTexture and tex:GetTexture() then
            DarkenTexture(tex, tint)
        end
    end

    -- DragonflightUI custom XP/Rep bar borders (overlay only, not fill/background)
    -- Use addon table references first (set by mainbars), fall back to _G
    local dfXpBar = addon.DfuiXpBar or _G["DragonUI_XPBar"]
    local dfRepBar = addon.DfuiRepBar or _G["DragonUI_RepBar"]
    if dfXpBar and dfXpBar.Border then
        DarkenTexture(dfXpBar.Border, tint)
    end
    if dfRepBar and dfRepBar.Border then
        DarkenTexture(dfRepBar.Border, tint)
    end

    -- Exhaustion tick (rested marker) — darken its child textures
    local tick = _G["ExhaustionTick"]
    if tick and tick:IsShown() and tick.GetRegions then
        for _, region in ipairs({ tick:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                DarkenTexture(region, tint)
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- MAIN BAR ART: the art frame, gryphons/dragons, dividers, page arrows
-- These are purely decorative chrome, safe to darken entirely.
-- -----------------------------------------------------------------------
local function DarkenMainBarArt(tint)
    -- MainMenuBarArtFrame: all regions are decorative art
    local artFrame = _G["MainMenuBarArtFrame"]
    if artFrame and artFrame.GetRegions then
        local regions = { artFrame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                DarkenTexture(region, tint)
            end
        end
    end

    -- Gryphons / Dragons (endcaps) — these are Texture objects
    DarkenGlobal("MainMenuBarLeftEndCap", tint)
    DarkenGlobal("MainMenuBarRightEndCap", tint)

    -- DragonUI custom mainbar art frame (pUiMainBarArt)
    local pUiMainBarArt = _G["pUiMainBarArt"]
    if pUiMainBarArt and pUiMainBarArt.GetRegions then
        local regions = { pUiMainBarArt:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                DarkenTexture(region, tint)
            end
        end
    end

    -- DragonUI custom main bar textures (on pUiMainBar itself, marked as dividers)
    local pUiMainBar = _G["pUiMainBar"]
    if pUiMainBar then
        if pUiMainBar.GetRegions then
            local regions = { pUiMainBar:GetRegions() }
            for _, region in ipairs(regions) do
                if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                    -- Only darken if it's a divider or background, not a button icon
                    if region._isDragonUIDivider then
                        DarkenTexture(region, tint)
                    end
                end
            end
        end

        -- NineSlice BorderArt frame: the wrapping border around the action bar
        local NINESLICE_PIECES = {
            "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
            "TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center"
        }
        if pUiMainBar.BorderArt then
            for _, pieceName in ipairs(NINESLICE_PIECES) do
                local piece = pUiMainBar.BorderArt[pieceName]
                if piece and piece.GetObjectType and piece:GetObjectType() == "Texture" then
                    DarkenTexture(piece, tint)
                end
            end
        end
        -- NineSlice Background frame
        if pUiMainBar.Background then
            for _, pieceName in ipairs(NINESLICE_PIECES) do
                local piece = pUiMainBar.Background[pieceName]
                if piece and piece.GetObjectType and piece:GetObjectType() == "Texture" then
                    DarkenTexture(piece, tint)
                end
            end
        end
    end

    -- DragonUI stance bar frame textures
    local pUiStanceBar = _G["pUiStanceBar"]
    if pUiStanceBar and pUiStanceBar.GetRegions then
        local regions = { pUiStanceBar:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                DarkenTexture(region, tint)
            end
        end
    end

    -- DragonUI pet bar frame textures
    local pUiPetBar = _G["pUiPetBar"]
    if pUiPetBar and pUiPetBar.GetRegions then
        local regions = { pUiPetBar:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                DarkenTexture(region, tint)
            end
        end
    end

end

-- -----------------------------------------------------------------------
-- UNIT FRAME BORDERS: darken ONLY the border/background textures,
-- never the portrait or health/mana bar fill.
-- -----------------------------------------------------------------------
-- Party pet art lives two anonymous frames deep (PartyFrameTemplates.xml), so GetRegions() never reaches it.
local function DarkenNestedPartyArt(frame, tint, depth)
    if not frame or (depth or 0) > 3 then return end

    if frame.GetRegions then
        for _, region in ipairs({ frame:GetRegions() }) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local path = region.GetTexture and region:GetTexture()
                -- Anchored match keeps the -Flash highlight variant out.
                if type(path) == "string" and path:upper():find("UI%-PARTYFRAME$") then
                    DarkenTexture(region, tint)
                end
            end
        end
    end

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            DarkenNestedPartyArt(child, tint, (depth or 0) + 1)
        end
    end
end

-- Classification is a pure function of the texture path, so memoise it and recompute only on path change.
local function ClassifyUnitFrameRegion(region)
    local texPath = region.GetTexture and region:GetTexture()
    if type(texPath) ~= "string" then texPath = "" end
    if region.__DragonUI_DarkPath ~= texPath then
        local upper = texPath:upper()
        region.__DragonUI_DarkPath = texPath
        region.__DragonUI_DarkNameBg = upper:find("NAMEBACKGROUND") and true or false
        region.__DragonUI_DarkBorder = (upper:find("BORDER") or upper:find("BACKGROUND")
                                        or upper:find("INCOMBAT") or upper:find("THREAT")
                                        or upper:find("UIUNITFRAME")) and true or false
    end
    return region.__DragonUI_DarkNameBg, region.__DragonUI_DarkBorder
end

-- Darken only textures whose path contains BORDER or BACKGROUND keywords
local function DarkenFrameBorderTextures(frame, tint, nameBgTint)
    if not frame or not frame.GetRegions then return end
    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            if IsTargetFocusNameBackgroundTexture(region) then
                DarkenTexture(region, nameBgTint)
            else
                -- Skip other NameBackground textures (non target/focus).
                local isNameBg, isBorder = ClassifyUnitFrameRegion(region)
                if not isNameBg then
                    if isBorder or region:GetDrawLayer() == "OVERLAY" then
                        DarkenTexture(region, tint)
                    end
                end
            end
        end
    end
end

local function DarkenUnitFrameBorders(tint)
    local nameBgTint = GetTargetFocusNameBackgroundTint(tint)

    -- Player frame (Blizzard)
    DarkenFrameBorderTextures(_G["PlayerFrame"], tint, nameBgTint)
    local playerTex = _G["PlayerFrameTexture"]
    if playerTex then DarkenTexture(playerTex, tint) end
    local playerStatus = _G["PlayerStatusTexture"]
    if playerStatus then DarkenTexture(playerStatus, tint) end

    -- DragonUI custom player frame border/background/decoration
    local dragonFrame = _G["DragonUIUnitframeFrame"]
    if dragonFrame then
        -- Main DragonUI border (the actual visible border)
        if dragonFrame.PlayerFrameBorder then
            DarkenTexture(dragonFrame.PlayerFrameBorder, tint)
        end
        local borderGlobal = _G["DragonUIPlayerFrameBorder"]
        if borderGlobal and borderGlobal ~= dragonFrame.PlayerFrameBorder then
            DarkenTexture(borderGlobal, tint)
        end
        -- Background
        if dragonFrame.PlayerFrameBackground then
            DarkenTexture(dragonFrame.PlayerFrameBackground, tint)
        end
        local bgGlobal = _G["DragonUIPlayerFrameBackground"]
        if bgGlobal and bgGlobal ~= dragonFrame.PlayerFrameBackground then
            DarkenTexture(bgGlobal, tint)
        end
        -- Deco (small dot decoration)
        if dragonFrame.PlayerFrameDeco then
            DarkenTexture(dragonFrame.PlayerFrameDeco, tint)
        end
        -- Dragon decoration (the creature art)
        if dragonFrame.PlayerDragonDecoration then
            DarkenTexture(dragonFrame.PlayerDragonDecoration, tint)
        end
        -- Fat bar + decoration border overlay
        if dragonFrame.BorderOverlayTexture then
            DarkenTexture(dragonFrame.BorderOverlayTexture, tint)
        end
    end

    -- Vehicle border (when in vehicle)
    local vehicleTex = _G["PlayerFrameVehicleTexture"]
    if vehicleTex then DarkenTexture(vehicleTex, tint) end

    -- Target frame
    DarkenFrameBorderTextures(_G["TargetFrame"], tint, nameBgTint)
    local targetTex = _G["TargetFrameTexture"]
    if targetTex then DarkenTexture(targetTex, tint) end
    -- DragonUI custom target border/background (target_style factory puts the
    -- border on a child frame, so DarkenFrameBorderTextures misses it)
    local dragonTargetBorder = _G["DragonUI_TargetBorder"]
    if dragonTargetBorder then DarkenTexture(dragonTargetBorder, tint) end
    local dragonTargetBG = _G["DragonUI_TargetBG"]
    if dragonTargetBG then DarkenTexture(dragonTargetBG, tint) end
    local dragonTargetElite = _G["DragonUI_TargetElite"]
    if dragonTargetElite then DarkenTexture(dragonTargetElite, tint) end

    DarkenFrameBorderTextures(_G["TargetFrameToT"], tint, nameBgTint)

    -- DragonUI custom ToT border/background (created by small_frame factory)
    local totBorder = _G["ToTBorder"]
    if totBorder then DarkenTexture(totBorder, tint) end
    local totBg = _G["ToTBG"]
    if totBg then DarkenTexture(totBg, tint) end

    -- Focus frame
    DarkenFrameBorderTextures(_G["FocusFrame"], tint, nameBgTint)
    local focusTex = _G["FocusFrameTexture"]
    if focusTex then DarkenTexture(focusTex, tint) end
    -- DragonUI custom focus border/background (same child-frame issue as target)
    local dragonFocusBorder = _G["DragonUI_FocusBorder"]
    if dragonFocusBorder then DarkenTexture(dragonFocusBorder, tint) end
    local dragonFocusBG = _G["DragonUI_FocusBG"]
    if dragonFocusBG then DarkenTexture(dragonFocusBG, tint) end
    local dragonFocusElite = _G["DragonUI_FocusElite"]
    if dragonFocusElite then DarkenTexture(dragonFocusElite, tint) end

    DarkenFrameBorderTextures(_G["FocusFrameToT"], tint, nameBgTint)

    -- DragonUI custom ToF border/background (created by small_frame factory)
    local tofBorder = _G["ToFBorder"]
    if tofBorder then DarkenTexture(tofBorder, tint) end
    local tofBg = _G["ToFBG"]
    if tofBg then DarkenTexture(tofBg, tint) end

    -- Pet frame
    DarkenFrameBorderTextures(_G["PetFrame"], tint, nameBgTint)
    local petTex = _G["PetFrameTexture"]
    if petTex then DarkenTexture(petTex, tint) end

    -- DragonUI custom pet frame border/background
    local petBorder = _G["DragonUIPetFrameBorder"]
    if petBorder then DarkenTexture(petBorder, tint) end
    local petBg = _G["DragonUIPetFrameBackground"]
    if petBg then DarkenTexture(petBg, tint) end

    -- Party frames
    for i = 1, 4 do
        DarkenFrameBorderTextures(_G["PartyMemberFrame" .. i], tint, nameBgTint)
        local partyTex = _G["PartyMemberFrame" .. i .. "Texture"]
        if partyTex then DarkenTexture(partyTex, tint) end
        local frame = _G["PartyMemberFrame" .. i]
        if frame and frame.DragonUI_BorderFrame and frame.DragonUI_BorderFrame.texture then
            DarkenTexture(frame.DragonUI_BorderFrame.texture, tint)
        end
        local petFrame = _G["PartyMemberFrame" .. i .. "PetFrame"]
        DarkenFrameBorderTextures(petFrame, tint, nameBgTint)
        DarkenNestedPartyArt(petFrame, tint, 0)
    end
end

-- -----------------------------------------------------------------------
-- MINIMAP: darken border textures only
-- -----------------------------------------------------------------------
local function DarkenMinimapBorders(tint)
    -- DragonUI custom circular border (Minimap.Circle) — this IS the visible border
    local minimapFrame = _G["Minimap"]
    if minimapFrame and minimapFrame.Circle then
        DarkenTexture(minimapFrame.Circle, tint)
    end

    -- Original Blizzard border (may be hidden but darken for safety)
    local border = _G["MinimapBorder"]
    if border then DarkenTexture(border, tint) end

    -- Top border (DragonUI custom zone text bar)
    local borderTop = _G["MinimapBorderTop"]
    if borderTop then DarkenTexture(borderTop, tint) end

    -- Tracking frame border region
    local trackingFrame = _G["MiniMapTrackingFrame"]
    if trackingFrame and trackingFrame.GetRegions then
        local regions = { trackingFrame:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local layer = region:GetDrawLayer()
                if layer == "OVERLAY" or layer == "BORDER" then
                    DarkenTexture(region, tint)
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- BAG BUTTONS: darken ONLY border/chrome textures, not bag icons.
-- DragonUI bags use customBorder (overlay) and background textures.
-- -----------------------------------------------------------------------
local function DarkenBagBorders(tint)
    -- Individual bag slots (CharacterBag0-3Slot) have:
    --   .customBorder = bag border overlay (OVERLAY)
    --   .background   = bg texture (BACKGROUND)
    local bagSlotNames = {
        "CharacterBag0Slot",
        "CharacterBag1Slot",
        "CharacterBag2Slot",
        "CharacterBag3Slot",
    }
    for _, name in ipairs(bagSlotNames) do
        local btn = _G[name]
        if btn then
            if btn.customBorder then DarkenTexture(btn.customBorder, tint) end
            if btn.background then DarkenTexture(btn.background, tint) end
        end
    end

    -- KeyRing: The NormalTexture (bag-reagent-border-2x) covers the entire button
    -- area including the icon. Use same approach as backpack: create a border-only
    -- overlay using bag-border-2x (the ring used on regular bag slots) and darken that.
    local keyring = _G["KeyRingButton"]
    if keyring then
        if not keyring.__DragonUI_DarkBorder then
            local border = keyring:CreateTexture(nil, "OVERLAY", nil, 7)
            -- Anchor to the NormalTexture which defines the visible border area
            local normalTex = keyring:GetNormalTexture()
            if normalTex then
                border:SetAllPoints(normalTex)
            else
                border:SetAllPoints(keyring)
            end
            -- Use bag-border-2x: the border ring atlas (same one used on regular bag slots)
            border:set_atlas("bag-border-2x")
            border:Hide()
            keyring.__DragonUI_DarkBorder = border
        end
        local border = keyring.__DragonUI_DarkBorder
        border:SetVertexColor(tint[1], tint[2], tint[3])
        border:Show()
        DarkModeModule.darkenedTextures[border] = true
        if not border.__DragonUI_OrigColor then
            border.__DragonUI_OrigColor = { 1, 1, 1, 1 }
        end
    end

    -- Main backpack border: handled separately via cutout overlay (see DarkenBackpackCutout)
end

-- -----------------------------------------------------------------------
-- MAIN BACKPACK: the backpack icon and border are baked into one texture,
-- so we overlay a cutout border texture on top and darken THAT.
-- -----------------------------------------------------------------------
local function DarkenBackpackCutout(tint)
    local backpack = _G["MainMenuBarBackpackButton"]
    if not backpack then return end

    -- Create the cutout overlay once, reuse on subsequent calls
    if not backpack.__DragonUI_DarkCutout then
        local cutout = backpack:CreateTexture(nil, "ARTWORK", nil, 7)
        cutout:SetTexture("Interface\\AddOns\\DragonUI\\Textures\\Bags\\bagslotCutout")
        local bw, bh = backpack:GetWidth(), backpack:GetHeight()
        cutout:SetWidth(bw + 1)
        cutout:SetHeight(bh + 1)
        cutout:SetPoint("CENTER", backpack, "CENTER", 0.1, 0.1)
        cutout:Hide()
        backpack.__DragonUI_DarkCutout = cutout
    end

    local cutout = backpack.__DragonUI_DarkCutout
    cutout:SetVertexColor(tint[1], tint[2], tint[3])
    cutout:Show()
    -- Track it for clean restore
    DarkModeModule.darkenedTextures[cutout] = true
    -- Store a flag so RestoreTexture knows to hide it
    if not cutout.__DragonUI_OrigColor then
        cutout.__DragonUI_OrigColor = { 1, 1, 1, 1 }
    end
end

-- -----------------------------------------------------------------------
-- MICRO MENU: darken ONLY DragonUIBackground textures (the button chrome),
-- NEVER the normal/pushed textures (those are the icons in DragonUI).
-- -----------------------------------------------------------------------
local function DarkenMicroMenuBorders(tint)
    local microNames = {
        "CharacterMicroButton",
        "SpellbookMicroButton",
        "TalentMicroButton",
        "AchievementMicroButton",
        "QuestLogMicroButton",
        "SocialsMicroButton",
        "PVPMicroButton",
        "LFDMicroButton",
        "MainMenuMicroButton",
        "HelpMicroButton",
    }
    for _, name in ipairs(microNames) do
        local btn = _G[name]
        if btn then
            -- DragonUI replaces normal/pushed with icon art.
            -- The actual background/chrome is stored in DragonUIBackground fields.
            if btn.DragonUIBackground then
                DarkenTexture(btn.DragonUIBackground, tint)
            end
            if btn.DragonUIBackgroundPushed then
                DarkenTexture(btn.DragonUIBackgroundPushed, tint)
            end
            -- DO NOT touch GetNormalTexture/GetPushedTexture — those are icons
        end
    end
end

-- -----------------------------------------------------------------------
-- ADDON BUTTON SKINNING: darken the circle border overlay on minimap buttons
-- -----------------------------------------------------------------------
local function DarkenAddonButtonBorders(tint)
    -- Scan Minimap and MinimapBackdrop children for skinned addon buttons
    local parents = { _G["Minimap"], _G["MinimapBackdrop"] }
    for _, parent in ipairs(parents) do
        if parent and parent.GetChildren then
            for _, child in ipairs({ parent:GetChildren() }) do
                if child.DragonUI_Skinned and child.circle then
                    DarkenTexture(child.circle, tint)
                end
            end
        end
    end
end

-- -----------------------------------------------------------------------
-- COMPACT RAID FRAME MANAGER (addon): manager shell + toggle button chrome
-- -----------------------------------------------------------------------
local COMPACT_RAIDFRAME_ADDONS = {
    CompactRaidFrame = true,
    CompactRaidFrames = true,
    Blizzard_CompactRaidFrames = true,
}

local function DarkenFrameRootTextures(frame, tint, skipNormalTexture)
    if not frame or not frame.GetRegions then return end
    local normalTex = skipNormalTexture and frame.GetNormalTexture and frame:GetNormalTexture()
    for _, region in ipairs({ frame:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" and region ~= normalTex then
            DarkenTexture(region, tint)
        end
    end
end

local function DarkenCompactRaidFrameManager(tint)
    local manager = _G["CompactRaidFrameManager"]
    if manager then
        DarkenFrameRootTextures(manager, tint)
    end

    local toggle = _G["CompactRaidFrameManagerToggleButton"]
        or (manager and manager.toggleButton)
    if toggle then
        DarkenFrameRootTextures(toggle, tint, true)
        local normal = toggle.GetNormalTexture and toggle:GetNormalTexture()
        if normal then
            DarkenTexture(normal, tint)
        end
    end

    local borderFrame = _G["CompactRaidFrameContainerBorderFrame"]
    if borderFrame then
        DarkenFrameRootTextures(borderFrame, tint)
    end
end

-- -----------------------------------------------------------------------
-- CASTBAR: darken border only
local function DarkenCastbarBorders(tint)
    -- Blizzard CastingBarFrame
    local castbar = _G["CastingBarFrame"]
    if castbar and castbar.GetRegions then
        local regions = { castbar:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                local layer = region:GetDrawLayer()
                -- Border and overlay textures but not the bar fill
                if layer == "OVERLAY" or layer == "BORDER" or layer == "ARTWORK" then
                    local tex = region:GetTexture()
                    if type(tex) == "string" then
                        -- Skip the actual status bar fill textures
                        local texUpper = tex:upper()
                        if not texUpper:find("STATUSBAR") and not texUpper:find("UI%-STATUSBAR") then
                            DarkenTexture(region, tint)
                        end
                    else
                        DarkenTexture(region, tint)
                    end
                end
            end
        end
    end

    -- DragonUI custom castbars (player, target, focus)
    local dragonCastbars = {
        "DragonUIPlayerCastbar",
        "DragonUITargetCastbar",
        "DragonUIFocusCastbar",
    }
    for _, name in ipairs(dragonCastbars) do
        local bar = _G[name]
        if bar and bar.GetRegions then
            -- Darken ARTWORK/BACKGROUND layer textures (border + bg) but SKIP icons
            for _, region in ipairs({ bar:GetRegions() }) do
                if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                    local layer = region:GetDrawLayer()
                    if layer == "ARTWORK" or layer == "BACKGROUND" then
                        -- Skip spell icon textures (named "...Icon") and icon border (UI-Quickslot2)
                        local rName = region.GetName and region:GetName()
                        if rName and rName:find("Icon") then
                            -- This is the castbar spell icon — do NOT darken
                        else
                            local tex = region.GetTexture and region:GetTexture()
                            if type(tex) == "string" and tex:find("UI%-Quickslot") then
                                -- This is the icon border ring — do NOT darken
                            else
                                DarkenTexture(region, tint)
                            end
                        end
                    end
                end
            end
        end
        -- Same art as the action button NormalTexture, so it takes the same tint to stay in step.
        local spellIcon = _G[name .. "Icon"]
        if spellIcon and spellIcon.ModernBorder then
            DarkenTexture(spellIcon.ModernBorder, tint)
        end

        -- Darken the text background frame border
        local textBG = _G[name .. "TextBG"]
        if textBG and textBG.GetRegions then
            for _, region in ipairs({ textBG:GetRegions() }) do
                if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                    DarkenTexture(region, tint)
                end
            end
        end
    end
end

-- ============================================================================
-- APPLY / RESTORE SYSTEM
-- ============================================================================

-- Lightweight re-darkener for a single action button (called from hooks)
local function ReDarkenButton(button)
    if not DarkModeModule.applied then return end
    if not button then return end
    local tint = GetTintValues()
    local name = button:GetName()
    if not name then return end
    -- Re-darken NormalTexture (border) — check NormalTexture2 first for pet/stance buttons
    local normal = _G[name .. "NormalTexture2"] or _G[name .. "NormalTexture"]
                   or (button.GetNormalTexture and button:GetNormalTexture())
    if normal and normal.GetObjectType and normal:GetObjectType() == "Texture" then
        DarkenTexture(normal, tint)
        -- Re-install vertex color guard if texture was replaced (e.g. SetNormalTexture call)
        if not normal.__DragonUI_VCGuard then
            local ok = pcall(hooksecurefunc, normal, "SetVertexColor", GuardSetVertexColor)
            if ok then
                normal.__DragonUI_VCGuard = true
            end
        end
    end
    -- Re-darken background slot texture (created by DragonUI buttons module)
    if button.background and button.background.GetObjectType and button.background:GetObjectType() == "Texture" then
        DarkenTexture(button.background, tint)
    end
end

-- Forward declaration so ApplyDarkMode can reference RestoreDarkMode
local RestoreDarkMode

-- White aura mask reads lighter than action-bar chrome at the same vertex color; crush toward black.
local function GetAuraBorderTintValues()
    local tint = GetTintValues()
    auraTintCache[1], auraTintCache[2], auraTintCache[3] = tint[1] * tint[1], tint[2] * tint[2], tint[3] * tint[3]
    return auraTintCache
end

-- force=true: enable / intensity / custom color change (overwrites Auras color).
-- force=false/nil: login/profile apply — keep Auras color if the player set buff_color_user_override.
local function SyncAuraBorderColorFromDarkMode(tint, force)
    local modules = addon.db and addon.db.profile and addon.db.profile.modules
    if not modules then return end
    local ab = modules.auraborders
    if not ab then
        ab = {}
        modules.auraborders = ab
    end
    if tint then
        if not force and ab.buff_color_user_override then
            return
        end
        ab.buff_color = { r = tint[1], g = tint[2], b = tint[3] }
        ab.buff_color_user_override = false
    else
        ab.buff_color = { r = 0.2, g = 0.2, b = 0.2 }
        ab.buff_color_user_override = false
    end
    if addon.RefreshAuraBordersSystem then
        addon.RefreshAuraBordersSystem()
    end
end

-- forceAuraSync: when true, push dark-mode tint onto aura buff borders (and clear user override).
local function ApplyDarkMode(forceAuraSync)
    if DarkModeModule.applied then
        -- Texture refresh only — do not reset aura border color mid-reapply.
        RestoreDarkMode(false)
        DarkModeModule.applied = false
    end

    local tint = GetTintValues()

    -- UF borders need a darker tint than other chrome
    local ufTint = GetUFTintValues()

    -- Apply surgically to each UI area (borders only)
    DarkenMainBarArt(tint)
    DarkenXPRepBorders(tint)
    DarkenActionButtonBorders(tint)
    DarkenStanceButtonBorders(tint)
    DarkenPetButtonBorders(tint)
    DarkenUnitFrameBorders(ufTint)
    DarkenMinimapBorders(tint)
    DarkenBagBorders(tint)
    DarkenMicroMenuBorders(tint)
    DarkenCastbarBorders(tint)
    DarkenBackpackCutout(tint)
    DarkenAddonButtonBorders(tint)
    DarkenCompactRaidFrameManager(tint)

    -- Re-pin hide_main_bar_background (art/gryphon alpha) after SetVertexColor.
    if addon.RefreshActionBarVisibility then
        addon.RefreshActionBarVisibility()
    end

    DarkModeModule.applied = true
    SyncAuraBorderColorFromDarkMode(GetAuraBorderTintValues(), forceAuraSync == true)

    if addon.RefreshNameplateCastIconChrome then
        addon.RefreshNameplateCastIconChrome()
    end

    -- Delayed re-darken for XP/Rep borders: mainbars creates DragonflightUI bars
    -- and restyles RetailUI textures at various times. A second pass at 0.5s
    -- guarantees we catch borders regardless of init ordering.
    addon:After(0.5, function()
        if not DarkModeModule.applied then return end
        local t = GetTintValues()
        DarkenXPRepBorders(t)
    end)
end

-- resetAuraBorders defaults to true (module/options disable). Pass false for texture-only re-apply.
RestoreDarkMode = function(resetAuraBorders)
    if resetAuraBorders == nil then
        resetAuraBorders = true
    end

    if not DarkModeModule.applied then
        if resetAuraBorders then
            SyncAuraBorderColorFromDarkMode(nil, true)
        end
        return
    end

    -- Restore ALL tracked textures efficiently
    for texture in pairs(DarkModeModule.darkenedTextures) do
        RestoreTexture(texture)
    end
    DarkModeModule.darkenedTextures = {}

    -- Hide the backpack cutout overlay
    local backpack = _G["MainMenuBarBackpackButton"]
    if backpack and backpack.__DragonUI_DarkCutout then
        backpack.__DragonUI_DarkCutout:Hide()
    end

    -- Hide the keyring border overlay
    local keyring = _G["KeyRingButton"]
    if keyring and keyring.__DragonUI_DarkBorder then
        keyring.__DragonUI_DarkBorder:Hide()
    end

    DarkModeModule.applied = false
    if resetAuraBorders then
        SyncAuraBorderColorFromDarkMode(nil, true)
    end

    if addon.RefreshNameplateCastIconChrome then
        addon.RefreshNameplateCastIconChrome()
    end

    if addon.RefreshActionBarVisibility then
        addon.RefreshActionBarVisibility()
    end
end

local function RefreshDarkMode(forceAuraSync)
    if DarkModeModule.applied then
        RestoreDarkMode(false)
    end
    if IsModuleEnabled() then
        ApplyDarkMode(forceAuraSync == true)
    end
end

-- ============================================================================
-- PROFILE CHANGE HANDLER
-- ============================================================================

local function OnProfileChanged()
    if IsModuleEnabled() then
        RefreshDarkMode()
    else
        if addon:ShouldDeferModuleDisable("darkmode", DarkModeModule) then
            return
        end
        RestoreDarkMode()
    end
end

-- ============================================================================
-- INITIALIZATION
-- ============================================================================

-- -----------------------------------------------------------------------
-- ACTION BAR REFRESH HOOKS: Re-apply darkening when Blizzard resets
-- NormalTexture on ability moves, form changes, bar page changes, etc.
-- -----------------------------------------------------------------------
local function SetupBarRefreshHooks()
    if DarkModeModule.hooks.barRefreshHooked then return end

    -- Hook ActionButton_Update: fires when abilities move, bars swap, etc.
    -- Blizzard resets SetNormalTexture inside this, wiping our vertex color.
    hooksecurefunc("ActionButton_Update", function(button)
        if not DarkModeModule.applied then return end
        ReDarkenButton(button)
    end)

    -- Hook ActionButton_UpdateUsable: fires when usability changes (flight,
    -- shapeshift, range check) — Blizzard resets NormalTexture vertex color.
    if ActionButton_UpdateUsable then
        hooksecurefunc("ActionButton_UpdateUsable", function(button)
            if not DarkModeModule.applied then return end
            ReDarkenButton(button)
        end)
    end

    -- Hook ActionButton_ShowGrid: fires when dragging abilities to show empty slots
    hooksecurefunc("ActionButton_ShowGrid", function(button)
        if not DarkModeModule.applied then return end
        ReDarkenButton(button)
    end)

    -- Hook ActionButton_HideGrid: fires when dropping abilities
    if ActionButton_HideGrid then
        hooksecurefunc("ActionButton_HideGrid", function(button)
            if not DarkModeModule.applied then return end
            ReDarkenButton(button)
        end)
    end

    -- Hook PetActionBar_Update: fires when pet bar refreshes (summon, dismiss, action changes)
    if PetActionBar_Update then
        hooksecurefunc("PetActionBar_Update", function()
            if not DarkModeModule.applied then return end
            addon:After(0.05, function()
                if not DarkModeModule.applied then return end
                local tint = GetTintValues()
                DarkenPetButtonBorders(tint)
            end)
        end)
    end

    DarkModeModule.hooks.barRefreshHooked = true
end

-- -----------------------------------------------------------------------
-- VERTEX COLOR GUARDS: Hook SetVertexColor on every action/stance/pet
-- button NormalTexture so that ANY external vertex color reset (range
-- checks in ActionButton_OnUpdate, usability updates, ShowGrid, etc.)
-- is immediately overridden with the dark mode tint.
-- This is the definitive fix for intermittent border depaint.
-- -----------------------------------------------------------------------
local function GuardSetVertexColor(self)
    if not DarkModeModule.applied then return end
    if self.__DragonUI_SettingDark then return end
    self.__DragonUI_SettingDark = true
    local tint = GetTintValues()
    self:SetVertexColor(tint[1], tint[2], tint[3])
    self.__DragonUI_SettingDark = nil
end

local function GuardNameBackgroundVertexColor(self)
    if not DarkModeModule.applied then return end
    if self.__DragonUI_SettingDark then return end
    if not IsTargetFocusNameBackgroundTexture(self) then return end
    if (TARGET_FOCUS_NAME_BG_DARKEN_FACTOR or 0) <= 0 then return end

    local ufTint = GetUFTintValues()
    local nameTint = GetTargetFocusNameBackgroundTint(ufTint)
    self.__DragonUI_SettingDark = true
    self:SetVertexColor(nameTint[1], nameTint[2], nameTint[3])
    self.__DragonUI_SettingDark = nil
end

local function InstallNameBackgroundVertexGuards()
    local names = { "TargetFrameNameBackground", "FocusFrameNameBackground" }
    for _, name in ipairs(names) do
        local tex = _G[name]
        if tex and not tex.__DragonUI_NameBGVCGuard then
            hooksecurefunc(tex, "SetVertexColor", GuardNameBackgroundVertexColor)
            tex.__DragonUI_NameBGVCGuard = true
        end
    end
end

local function InstallVertexColorGuards()
    -- Idempotent: Extra Bar buttons may not exist on the first PEW pass.
    for n = 1, #ACTION_BUTTON_NAMES, 2 do
        local normal = _G[ACTION_BUTTON_NAMES[n + 1]]
        if not normal then
            local btn = _G[ACTION_BUTTON_NAMES[n]]
            if btn and btn.GetNormalTexture then normal = btn:GetNormalTexture() end
        end
        if normal and not normal.__DragonUI_VCGuard then
            hooksecurefunc(normal, "SetVertexColor", GuardSetVertexColor)
            normal.__DragonUI_VCGuard = true
        end
    end

    -- Stance / Shapeshift NormalTextures
    for i = 1, 10 do
        local normal = _G["ShapeshiftButton" .. i .. "NormalTexture"]
        if not normal then
            local btn = _G["ShapeshiftButton" .. i]
            if btn and btn.GetNormalTexture then normal = btn:GetNormalTexture() end
        end
        if normal and not normal.__DragonUI_VCGuard then
            hooksecurefunc(normal, "SetVertexColor", GuardSetVertexColor)
            normal.__DragonUI_VCGuard = true
        end
    end

    -- Pet button NormalTextures
    for i = 1, 10 do
        local normal = _G["PetActionButton" .. i .. "NormalTexture2"]
                       or _G["PetActionButton" .. i .. "NormalTexture"]
        if not normal then
            local btn = _G["PetActionButton" .. i]
            if btn and btn.GetNormalTexture then normal = btn:GetNormalTexture() end
        end
        if normal and not normal.__DragonUI_VCGuard then
            hooksecurefunc(normal, "SetVertexColor", GuardSetVertexColor)
            normal.__DragonUI_VCGuard = true
        end
    end

    -- Target/Focus NameBackground texture guards (selection/faction banner).
    InstallNameBackgroundVertexGuards()

    DarkModeModule.hooks.vertexGuardsInstalled = true
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")

eventFrame:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == "DragonUI" then
        if not IsModuleEnabled() then return end

        addon:After(0.5, function()
            if addon.db and addon.db.RegisterCallback then
                addon.db.RegisterCallback(DarkModeModule, "OnProfileChanged", OnProfileChanged)
                addon.db.RegisterCallback(DarkModeModule, "OnProfileCopied", OnProfileChanged)
                addon.db.RegisterCallback(DarkModeModule, "OnProfileReset", OnProfileChanged)
            end
        end)

    elseif event == "ADDON_LOADED" and COMPACT_RAIDFRAME_ADDONS[arg1] then
        if not DarkModeModule.applied then return end
        addon:After(0.1, function()
            if not DarkModeModule.applied then return end
            DarkenCompactRaidFrameManager(GetTintValues())
        end)

    elseif event == "PLAYER_ENTERING_WORLD" then
        if not IsModuleEnabled() then return end

        -- Setup hooks ONCE (before ApplyDarkMode so they catch future updates)
        SetupBarRefreshHooks()
        InstallVertexColorGuards()
        InstallNameBackgroundVertexGuards()

        -- Hook player frame refresh so dark mode re-applies after decoration/fat bar changes
        if not DarkModeModule.hooks.playerFrameHooked then
            if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
                local origRefresh = addon.PlayerFrame.RefreshPlayerFrame
                addon.PlayerFrame.RefreshPlayerFrame = function(...)
                    origRefresh(...)
                    -- Re-darken UF borders after player frame rebuilds its textures
                    if DarkModeModule.applied then
                        addon:After(0.05, function()
                            if not DarkModeModule.applied then return end
                            local ufTint = GetUFTintValues()
                            DarkenUnitFrameBorders(ufTint)
                        end)
                    end
                end
                -- Also update the .Refresh alias
                addon.PlayerFrame.Refresh = addon.PlayerFrame.RefreshPlayerFrame
            end

            -- Hook PlayerFrame_UpdateArt — Blizzard calls this during reload/vehicle transitions
            -- which triggers ChangePlayerframe() and recreates decoration textures, losing dark tints
            if PlayerFrame_UpdateArt then
                hooksecurefunc("PlayerFrame_UpdateArt", function()
                    if DarkModeModule.applied then
                        addon:After(0.1, function()
                            if not DarkModeModule.applied then return end
                            local ufTint = GetUFTintValues()
                            DarkenUnitFrameBorders(ufTint)
                        end)
                    end
                end)
            end

            DarkModeModule.hooks.playerFrameHooked = true
        end

        -- Hook TargetFrame_Update / FocusFrame_Update so dark mode re-applies
        -- to custom DragonUI border/background textures after Blizzard refreshes.
        -- Throttled to avoid excessive re-darkening on rapid fire events.
        if not DarkModeModule.hooks.targetFocusHooked then
            local lastUFRefresh = 0
            local function ThrottledUFRedarken()
                if not DarkModeModule.applied then return end
                local now = GetTime()
                if now - lastUFRefresh < 0.15 then return end
                lastUFRefresh = now

                -- Ensure guards exist even if a frame initialized late.
                InstallNameBackgroundVertexGuards()

                -- Apply immediately to avoid one-frame flashes when target/focus
                -- backgrounds are refreshed to their default colors.
                local ufTint = GetUFTintValues()
                DarkenUnitFrameBorders(ufTint)

                -- Keep a short safety pass for delayed Blizzard refreshes.
                addon:After(0.03, function()
                    if not DarkModeModule.applied then return end
                    local delayedTint = GetUFTintValues()
                    DarkenUnitFrameBorders(delayedTint)
                end)

                -- Extra pass for first target/focus creation right after reload.
                addon:After(0.10, function()
                    if not DarkModeModule.applied then return end
                    local delayedTint = GetUFTintValues()
                    DarkenUnitFrameBorders(delayedTint)
                end)
            end

            if TargetFrame_Update then
                hooksecurefunc("TargetFrame_Update", ThrottledUFRedarken)
            end
            if FocusFrame_Update then
                hooksecurefunc("FocusFrame_Update", ThrottledUFRedarken)
            end

            DarkModeModule.hooks.targetFocusHooked = true
        end

        -- Register bar-change events for full re-darken of all buttons
        if not DarkModeModule.hooks.barEventsRegistered then
            self:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
            self:RegisterEvent("UPDATE_BONUS_ACTIONBAR")
            self:RegisterEvent("ACTIONBAR_PAGE_CHANGED")
            self:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
            self:RegisterEvent("SPELL_UPDATE_USABLE")
            self:RegisterEvent("ACTIONBAR_UPDATE_STATE")
            self:RegisterEvent("PLAYER_REGEN_DISABLED")
            self:RegisterEvent("PLAYER_REGEN_ENABLED")
            self:RegisterEvent("PLAYER_TARGET_CHANGED")
            self:RegisterEvent("PLAYER_FOCUS_CHANGED")
            self:RegisterEvent("UNIT_ENTERED_VEHICLE")
            self:RegisterEvent("UNIT_EXITED_VEHICLE")
            self:RegisterEvent("PET_BAR_UPDATE")
            self:RegisterEvent("PLAYER_ALIVE")
            self:RegisterEvent("PLAYER_UNGHOST")
            self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS")
            DarkModeModule.hooks.barEventsRegistered = true
        end

        -- Apply immediately so the first target/focus after /reload is already dark.
        ApplyDarkMode()

        -- Keep delayed pass for late-created textures/modules.
        addon:After(0.3, function()
            if not IsModuleEnabled() then return end
            ApplyDarkMode()
        end)

        -- Second pass for castbars: target/focus castbars are created lazily
        -- by the castbar module at ~0.5s. Re-darken castbar borders after they exist.
        addon:After(0.8, function()
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenCastbarBorders(tint)
            -- Also catch addon buttons that may have loaded late
            DarkenAddonButtonBorders(tint)
            DarkenCompactRaidFrameManager(tint)
        end)

    elseif event == "UPDATE_SHAPESHIFT_FORM" or event == "UPDATE_BONUS_ACTIONBAR"
        or event == "ACTIONBAR_PAGE_CHANGED" then
        -- Form/stance/page changed — re-darken all action + stance buttons after a tiny delay
        -- to let Blizzard finish swapping textures first
        if not DarkModeModule.applied then return end
        addon:After(0.1, function()
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenActionButtonBorders(tint)
            DarkenStanceButtonBorders(tint)
            DarkenPetButtonBorders(tint)
        end)

    elseif event == "ACTIONBAR_SLOT_CHANGED" then
        -- A single slot changed (ability moved) — the ActionButton_Update hook
        -- handles individual buttons, but do a safety sweep after a short delay
        if not DarkModeModule.applied then return end
        addon:After(0.05, function()
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenActionButtonBorders(tint)
        end)

    elseif event == "SPELL_UPDATE_USABLE" or event == "ACTIONBAR_UPDATE_STATE" then
        -- These fire frequently during shapeshift/flight when Blizzard resets
        -- button textures. Delay so Blizzard finishes its own vertex color changes first.
        if not DarkModeModule.applied then return end
        if DarkModeModule.borderSweepPending then return end
        DarkModeModule.borderSweepPending = true
        addon:After(0.05, function()
            DarkModeModule.borderSweepPending = false
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenActionButtonBorders(tint)
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Combat entry: Blizzard calls ActionButton_UpdateUsable for all buttons,
        -- which resets NormalTexture vertex color. Re-apply after it finishes.
        if not DarkModeModule.applied then return end
        addon:After(0.1, function()
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenActionButtonBorders(tint)
        end)

    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Combat exit: Blizzard runs all deferred frame updates at once,
        -- resetting NormalTexture vertex colors across bars and unit frames.
        if not DarkModeModule.applied then return end
        addon:After(0.15, function()
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenActionButtonBorders(tint)
            DarkenStanceButtonBorders(tint)
            DarkenPetButtonBorders(tint)
            DarkenMainBarArt(tint)
            local ufTint = GetUFTintValues()
            DarkenUnitFrameBorders(ufTint)
        end)

    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        -- Vehicle transitions rebuild player frame art and swap action bars.
        if arg1 ~= "player" then return end
        if not DarkModeModule.applied then return end
        addon:After(0.2, function()
            if not DarkModeModule.applied then return end
            local ufTint = GetUFTintValues()
            DarkenUnitFrameBorders(ufTint)
            local tint = GetTintValues()
            DarkenMainBarArt(tint)
            DarkenActionButtonBorders(tint)
        end)
        -- Second pass — vehicle art rebuild can be slow
        addon:After(0.5, function()
            if not DarkModeModule.applied then return end
            local ufTint = GetUFTintValues()
            DarkenUnitFrameBorders(ufTint)
        end)

    elseif event == "PET_BAR_UPDATE" then
        -- Pet bar refreshed (summon, dismiss, pet action changes)
        if not DarkModeModule.applied then return end
        addon:After(0.1, function()
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenPetButtonBorders(tint)
        end)

    elseif event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST" then
        -- Death/resurrect changes player frame art
        if not DarkModeModule.applied then return end
        addon:After(0.2, function()
            if not DarkModeModule.applied then return end
            local ufTint = GetUFTintValues()
            DarkenUnitFrameBorders(ufTint)
        end)

    elseif event == "UPDATE_SHAPESHIFT_FORMS" then
        -- Form list changed (learned new form) — stance buttons may be rebuilt
        if not DarkModeModule.applied then return end
        addon:After(0.15, function()
            if not DarkModeModule.applied then return end
            local tint = GetTintValues()
            DarkenStanceButtonBorders(tint)
        end)

    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        -- Re-darken unit frame borders after target/focus change.
        -- The target_style factory's custom textures persist across target
        -- changes, but Blizzard's TargetFrame_Update may reset some
        -- Blizzard texture vertex colors that we also darken.
        if not DarkModeModule.applied then return end

        InstallNameBackgroundVertexGuards()

        local ufTint = GetUFTintValues()
        DarkenUnitFrameBorders(ufTint)

        addon:After(0.03, function()
            if not DarkModeModule.applied then return end
            local delayedTint = GetUFTintValues()
            DarkenUnitFrameBorders(delayedTint)
        end)

        addon:After(0.10, function()
            if not DarkModeModule.applied then return end
            local delayedTint = GetUFTintValues()
            DarkenUnitFrameBorders(delayedTint)
        end)
    end
end)

-- Export for external use
addon.ApplyDarkMode = ApplyDarkMode
addon.RestoreDarkMode = RestoreDarkMode
addon.RefreshDarkMode = RefreshDarkMode

-- Lightweight re-darken for UF borders only (called from player.lua after dragon recreation)
addon.RefreshDarkModeUnitFrames = function()
    if not DarkModeModule.applied then return end
    local ufTint = GetUFTintValues()
    DarkenUnitFrameBorders(ufTint)
end

-- Plates recycle constantly, so their chrome pulls the tint on demand instead of being swept.
addon.GetDarkModeTint = function()
    if not IsModuleEnabled() or not DarkModeModule.applied then return nil end
    return GetTintValues()
end

-- Re-darken castbar borders (called from castbar.lua after lazy castbar creation)
addon.RefreshDarkModeCastbars = function()
    if not DarkModeModule.applied then return end
    local tint = GetTintValues()
    DarkenCastbarBorders(tint)
end

-- Re-darken XP/Rep bar borders (called from mainbars.lua after styling resets vertex colors)
addon.RefreshDarkModeXPRepBars = function()
    if not IsModuleEnabled() then return end
    if not DarkModeModule.applied then return end
    local tint = GetTintValues()
    DarkenXPRepBorders(tint)
end

-- Re-darken all action/stance/pet button borders (called from buttons.lua after restyling)
addon.RefreshDarkModeActionButtons = function()
    if not IsModuleEnabled() then return end
    if not DarkModeModule.applied then return end
    local tint = GetTintValues()
    DarkenActionButtonBorders(tint)
    DarkenStanceButtonBorders(tint)
    DarkenPetButtonBorders(tint)
    InstallVertexColorGuards()
end
