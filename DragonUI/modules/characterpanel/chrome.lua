local addon = select(2, ...)
local CP = addon.CharacterPanel

local ROCK = addon._dir .. "UI\\ui-background-rock"
local REDBUTTON = addon._dir .. "UI\\redbutton2x"

local STREAK_Y, STREAK_H = 21, 43

-- Every 4-corner chrome family the five 3.3.5a subframes declare, verified against FrameXML.
local VANILLA_CHROME = {
    "ui%-character%-charactertab",
    "ui%-character%-general",
    "ui%-petpaperdollframe%-bot",
    "skillframe%-bot",
    "ui%-talentframe%-bot",
    "ui%-character%-statbackground",
    -- Wooden decoration the list tabs draw over their body; reads as vanilla against metal chrome.
    "ui%-classtrainer%-horizontalbar",
    "ui%-classtrainer%-scrollbar",
    "ui%-character%-scrollbar",
}

local function isVanillaChrome(file)
    if type(file) ~= "string" then return false end
    local lower = file:lower()
    for _, pat in ipairs(VANILLA_CHROME) do
        if lower:find(pat) then return true end
    end
    return false
end

local hiddenRegions = {}

local function neuter(region)
    if region._duiChromeHidden then return end
    region._duiChromeHidden = true
    hiddenRegions[#hiddenRegions + 1] = region
    -- Textures have no script handlers, so surviving Blizzard's re-Show means neutering Show itself.
    region._duiShow = region.Show
    region.Show = region.Hide
end

local function restore(region)
    if not region._duiChromeHidden then return end
    region._duiChromeHidden = nil
    if region._duiShow then
        region.Show = region._duiShow
        region._duiShow = nil
    end
end

-- A reskinned subframe keeps NOTHING of its own art, so identity decides rather than a runtime match
-- on the texture path -- that match failed silently whenever a path had not resolved yet.
local function sweepOwnRegions(frame, hide)
    for _, region in ipairs({ frame:GetRegions() }) do
        if region.GetObjectType and region:GetObjectType() == "Texture" and not region._duiOwned then
            if hide then
                neuter(region)
                region:Hide()
            elseif region._duiChromeHidden then
                restore(region)
                region:Show()
            end
        end
    end
end

local function walkChrome(frame, hide, isSubframe)
    if not frame or not frame.GetRegions then return end

    if isSubframe then
        sweepOwnRegions(frame, hide)
    else
        local regions = { frame:GetRegions() }
        for i = 1, #regions do
            local region = regions[i]
            if region.GetObjectType and region:GetObjectType() == "Texture"
                and isVanillaChrome(region:GetTexture()) then
                if hide then
                    neuter(region)
                    region:Hide()
                else
                    restore(region)
                    region:Show()
                end
            end
        end
    end

    -- Scroll frames nest their own vanilla scrollbar art, so a top-level walk misses it.
    local children = { frame:GetChildren() }
    for i = 1, #children do
        walkChrome(children[i], hide)
    end
end

local function suppressChrome(frame)
    walkChrome(frame, true)
end

local function applyDimensions(cf)
    cf:SetWidth(CP.PANEL_WIDTH)
    cf:SetHeight(CP.PANEL_HEIGHT)
end

-- Blizzard centers the name over the wooden header; retail sits it in the metal title band.
local function applyTitle(cf)
    local title = _G.CharacterNameFrame
    if not title then return end
    title:ClearAllPoints()
    title:SetPoint("TOPLEFT", cf, "TOPLEFT", 58, -1)
    title:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -24, -1)
    title:SetHeight(20)

    local text = _G.CharacterNameText
    if not text then return end
    text:ClearAllPoints()
    text:SetPoint("TOP", title, "TOP", 0, -5)
    text:SetPoint("LEFT", title, "LEFT", 0, 0)
    text:SetPoint("RIGHT", title, "RIGHT", 0, 0)
end

-- xoffset is the only lever that moves a left-area panel without fighting the panel system.
local PANEL_X_NUDGE = 6

local function nudgePanel()
    local info = UIPanelWindows and UIPanelWindows["CharacterFrame"]
    if not info or info.xoffset == PANEL_X_NUDGE then return end
    info.xoffset = PANEL_X_NUDGE
    if _G.CharacterFrame and _G.CharacterFrame:IsShown() and UpdateUIPanelPositions then
        UpdateUIPanelPositions(_G.CharacterFrame)
    end
end

-- The Inset's ground is its rock and nothing else; the second sheet that used to cover it is gone
-- rather than managed, because it cannot fall out of step if it does not exist.
local function applyBackgrounds(cf)
    if not cf._duiRockBg then
        local bg = cf:CreateTexture(nil, "BACKGROUND", nil, -6)
        bg:SetTexture(ROCK, "REPEAT", "REPEAT")
        bg:SetHorizTile(true)
        bg:SetVertTile(true)
        bg:SetPoint("TOPLEFT", cf, "TOPLEFT", 2, -21)
        bg:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -2, 2)
        cf._duiRockBg = bg
    end

    -- The worn strip retail tiles under the title bar, which stops the rock reading as wallpaper.
    if not cf._duiStreaks then
        local streaks = cf:CreateTexture(nil, "BORDER")
        streaks:set_atlas("_UI-Frame-TopTileStreaks")
        streaks:SetHorizTile(true)
        streaks:SetHeight(STREAK_H)
        streaks:SetPoint("TOPLEFT", cf, "TOPLEFT", 6, -STREAK_Y)
        streaks:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -2, -STREAK_Y)
        cf._duiStreaks = streaks
    end

    CP.ApplyBodyBackground()
end

-- One setting drives every ground. `body` must track the insets or the strip between them reads as a
-- dark band; `streak` is an alpha, not a tint, because dark strokes on dark ground only stack.
local TINTS = {
    stone = { body = 1.0, inset = 1.0, sidebar = 1.0, paper = 1.0, streak = 1.0 },
    dark = { body = 0.45, inset = 0.45, sidebar = 0.45, paper = 0.8, streak = 0.35 },
}

function CP.ApplyBodyBackground()
    local cf = _G.CharacterFrame
    if not cf then return end

    local tint = CP:Config().dark_background and TINTS.dark or TINTS.stone

    if cf._duiRockBg then
        cf._duiRockBg:SetVertexColor(tint.body, tint.body, tint.body)
    end
    if cf._duiStreaks then
        cf._duiStreaks:SetAlpha(tint.streak)
    end
    if cf.Inset and cf.Inset.Bg then
        cf.Inset.Bg:SetVertexColor(tint.inset, tint.inset, tint.inset)
    end
    if cf.InsetRight and cf.InsetRight.Bg then
        cf.InsetRight.Bg:SetVertexColor(tint.sidebar, tint.sidebar, tint.sidebar)
    end
    -- The faction popup hangs off the panel, so it shades with it.
    if CP.DetailGround then
        CP.DetailGround:SetVertexColor(tint.body, tint.body, tint.body)
    end
    if CP.DetailPaper then
        CP.DetailPaper:SetVertexColor(tint.paper, tint.paper, tint.paper)
    end
end

local function applyNineSlice(cf)
    if cf._duiNineSlice then return end
    local layout = NineSliceUtils and NineSliceUtils.GetLayout("PortraitFrameTemplate")
    if not layout then return end
    NineSliceUtils.ApplyLayout(cf, layout)
    cf._duiNineSlice = true
end

-- Shared so any window we reskin closes with the same button.
function CP.ModernizeCloseButton(cb, owner, x, y)
    if not cb or cb._duiModernized then return end
    cb._duiModernized = true

    cb:SetSize(24, 24)
    cb:ClearAllPoints()
    cb:SetPoint("TOPRIGHT", owner, "TOPRIGHT", x or 1, y or 0)

    local nt = cb:GetNormalTexture()
    if nt then
        nt:SetTexture(REDBUTTON)
        nt:SetTexCoord(0.152344, 0.292969, 0.0078125, 0.304688)
    end
    local pt = cb:GetPushedTexture()
    if pt then
        pt:SetTexture(REDBUTTON)
        pt:SetTexCoord(0.152344, 0.292969, 0.320312, 0.617188)
    end
end

local function applyCloseButton()
    CP.ModernizeCloseButton(_G.CharacterFrameCloseButton, _G.CharacterFrame)
end

local function subframes()
    local out = {}
    for _, name in ipairs(CP.SUBFRAMES) do
        local f = _G[name]
        if f then out[#out + 1] = f end
    end
    return out
end

local NINESLICE_PIECES = {
    "TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
    "TopEdge", "BottomEdge", "LeftEdge", "RightEdge",
}

-- Blizzard's per-tab corner art is what closes off the bottom of the list panes, so the retail
-- chrome is swapped in and out per tab rather than replacing it everywhere.
local function reskinsThisTab(tabName)
    return CP.OWNED_TABS[tabName] and true or false
end

function CP.ApplyChromeForTab(tabName)
    local cf = _G.CharacterFrame
    if not cf or not cf._duiChromeBuilt then return end

    -- Which tab is genuinely up, not the name the caller passed: this runs from every subframe's
    -- OnShow, and load-on-demand Blizzard_TokenUI makes the last to fire differ between loads.
    local active = (CP.ActiveTabName and CP.ActiveTabName()) or tabName
    local retail = reskinsThisTab(active)

    for _, piece in ipairs(NINESLICE_PIECES) do
        local t = cf[piece]
        if t then if retail then t:Show() else t:Hide() end end
    end
    if cf._duiRockBg then if retail then cf._duiRockBg:Show() else cf._duiRockBg:Hide() end end
    -- Only on the tabs we draw ourselves, which are the only ones whose grounds it controls.
    if CP.SetSettingsCogShown then CP.SetSettingsCogShown(CP.OWNED_TABS[active] and true or false) end
    if cf.Inset then if retail then cf.Inset:Show() else cf.Inset:Hide() end end

    -- Suppressed on whether WE reskin that frame, never on which tab is active: one flag derived
    -- from the active tab let any OnShow restore PaperDollFrame's opaque bottom corner art.
    for _, frame in ipairs(subframes()) do
        walkChrome(frame, reskinsThisTab(frame:GetName()), true)
    end
end

-- walkChrome matches a vanilla region by the path it reports, and a path that had not resolved yet
-- left the art live -- dark on one load, gone on the next. One pass after the frame is up settles it.
local function hookFrameShow()
    local cf = _G.CharacterFrame
    if not cf or cf._duiChromeShowHooked then return end
    cf._duiChromeShowHooked = true
    cf:HookScript("OnShow", function()
        CP.ApplyChromeForTab(CP.ActiveTabName and CP.ActiveTabName() or "PaperDollFrame")
        -- The database is certainly up by now, so a builder's half-loaded config gets its real value.
        CP.ApplyBodyBackground()
        if CP.ApplyModelBackdrop then CP.ApplyModelBackdrop() end
    end)
end

local function hookSubframes()
    local cf = _G.CharacterFrame
    for _, frame in ipairs(subframes()) do
        if not frame._duiChromeHooked then
            frame._duiChromeHooked = true
            frame:HookScript("OnShow", function(self)
                CP.ApplyChromeForTab(self:GetName())
            end)
        end
        if cf then frame:SetFrameLevel(cf:GetFrameLevel() + CP.SUBFRAME_LEVEL) end
    end
    CP.ApplyChromeForTab(CP.ActiveTabName and CP.ActiveTabName() or "PaperDollFrame")
    hookFrameShow()
end

local function build()
    local cf = _G.CharacterFrame
    if not cf then return end

    if not cf._duiChromeBuilt then
        cf._duiChromeBuilt = true
        applyDimensions(cf)
        nudgePanel()
        applyTitle(cf)
        applyBackgrounds(cf)
        applyNineSlice(cf)
        applyCloseButton()
    end

    -- TokenFrame lives in Blizzard_TokenUI, which loads on demand — re-walk every pass.
    hookSubframes()
end

function CP.RestoreChrome()
    local cf = _G.CharacterFrame
    if not cf then return end
    for _, region in ipairs(hiddenRegions) do
        if region._duiShow then
            region.Show = region._duiShow
            region._duiShow = nil
        end
        region._duiChromeHidden = nil
        region:Show()
    end
    if cf._duiRockBg then cf._duiRockBg:Hide() end
    for _, piece in ipairs({ "TopLeftCorner", "TopRightCorner", "BottomLeftCorner",
                             "BottomRightCorner", "TopEdge", "BottomEdge", "LeftEdge", "RightEdge" }) do
        if cf[piece] then cf[piece]:Hide() end
    end
    cf:SetWidth(384)
    cf:SetHeight(512)
end

CP.SuppressChrome = suppressChrome

CP:RegisterBuilder("chrome", build)
