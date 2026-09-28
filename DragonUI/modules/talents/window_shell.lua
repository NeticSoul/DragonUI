-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

local addon = select(2, ...)
local TM = addon.TalentModule
local ns = TM.ns

local max, min = math.max, math.min
local ResetGroupPreviewTalentPoints = _G.ResetGroupPreviewTalentPoints

-- Background art ----------------------------------------------------------------------------------

local SPEC_SLUGS = {}
do
    local source = "warrior=arms,fury,protection paladin=holy,protection,retribution "
        .. "hunter=beastmastery,marksmanship,survival rogue=assassination,outlaw,subtlety "
        .. "priest=discipline,holy,shadow shaman=elemental,enhancement,restoration "
        .. "mage=arcane,fire,frost warlock=affliction,demonology,destruction "
        .. "druid=balance,feral,restoration deathknight=blood,frost,unholy"
    for slug, list in source:gmatch("(%l+)=([%l,]+)") do
        local specs = {}
        for spec in list:gmatch("%l+") do specs[#specs + 1] = spec end
        SPEC_SLUGS[slug] = specs
    end
end

local function backgroundAtlas(classToken, tree)
    local slug = type(classToken) == "string" and classToken:lower()
    local specs = slug and SPEC_SLUGS[slug]
    if not specs then return "talents-background-warrior-arms" end
    return "talents-background-" .. slug .. "-" .. (specs[tree] or specs[1])
end

local function artHeight()
    return ns.win:GetHeight() - (ns.ART_TOP + ns.FOOTER_H)
end

-- Cover-crop without distortion; the art's subject sits top-right, so that corner survives.
function ns.SetClassArt(classToken, tree, desaturate)
    local art = ns.classArt
    local entry = addon.atlasinfo[backgroundAtlas(classToken, tree)]
    if not entry then return end
    local width, height = entry[2], entry[3]
    local left, right, top, bottom = entry[4], entry[5], entry[6], entry[7]
    local regionW, regionH = ns.WIDTH, artHeight()
    if regionW * height > width * regionH then
        bottom = top + (bottom - top) * (regionH * width) / (regionW * height)
    else
        left = right - (right - left) * (regionW * height) / (regionH * width)
    end
    art:SetTexture(entry[1])
    art:SetTexCoord(left, right, top, bottom)
    art:SetDesaturated(desaturate and true or false)
    art:Show()
    ns.petArt:Hide()
end

function ns.SetPetArt(background)
    local kind = type(background) == "string" and background:match("^HunterPet(%a+)$")
    if kind == "Ferocity" or kind == "Tenacity" or kind == "Cunning" then
        ns.petArt:SetTexture(addon._dir .. "Talents\\Pet_" .. kind)
        ns.petArt:SetTexCoord(0, 1, 0, 1)
    end
    ns.petArt:Show()
    ns.classArt:Hide()
end

function ns.ArtifactName(classToken)
    if classToken == "DEATHKNIGHT" then return "DeathKnight" end
    if type(classToken) ~= "string" or not ns.KNOWN_CLASS[classToken] then return "Warrior" end
    return classToken:sub(1, 1) .. classToken:sub(2):lower()
end

function ns.DominantTree(pointsByTree, count)
    local best, bestPoints = 1, 0
    for tree = 1, count or #pointsByTree do
        local points = pointsByTree[tree] or 0
        if points > bestPoints then best, bestPoints = tree, points end
    end
    return best
end

-- Portrait and title ------------------------------------------------------------------------------

function ns.SetPortraitClass(classToken)
    if not (CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classToken]) then return end
    local portrait = ns.portrait
    portrait:ClearAllPoints()
    portrait:SetSize(57, 57)
    portrait:SetPoint("TOPLEFT", ns.win, "TOPLEFT", -3, 6)
    portrait:SetTexture(addon._dir .. "ClassIcons\\" .. classToken)
    portrait:SetTexCoord(0, 1, 0, 1)
end

function ns.SetPortraitUnit(unit)
    local portrait = ns.portrait
    portrait:ClearAllPoints()
    portrait:SetSize(58, 58)
    portrait:SetPoint("TOPLEFT", ns.win, "TOPLEFT", -3, 7)
    -- SetPortraitTexture keeps whatever texcoords the class icon left behind.
    portrait:SetTexCoord(0, 1, 0, 1)
    SetPortraitTexture(portrait, unit)
end

function ns.SetTitle(text)
    if ns.title then ns.title:SetText(text) end
end

-- Ambient clouds and dust -------------------------------------------------------------------------

local DUST = {
    { w = 1308, h = 774, lead = 300, drift = 600, period = 27, peak = 0.149, rise = 5, fade = 22 },
    { w = 800, h = 473, lead = 100, drift = 200, period = 36, peak = 0.137, rise = 5, fade = 31, flip = true },
}
local CLOUD_PERIOD = 80

-- Crop a layer to the art region through its texcoords; a ScrollFrame clip froze window drags.
local function clipLayer(tex, x0, y0, w, h, regionW, regionH, coords, flip)
    local ax, ay = max(x0, 0), max(y0, 0)
    local bx, by = min(x0 + w, regionW), min(y0 + h, regionH)
    if bx - ax < 1 or by - ay < 1 then
        tex:Hide()
        return
    end
    local l, r, t, b = coords[4], coords[5], coords[6], coords[7]
    local fromX, toX = (ax - x0) / w, (bx - x0) / w
    local fromY, toY = (ay - y0) / h, (by - y0) / h
    if flip then
        tex:SetTexCoord(r - (r - l) * fromX, r - (r - l) * toX, t + (b - t) * fromY, t + (b - t) * toY)
    else
        tex:SetTexCoord(l + (r - l) * fromX, l + (r - l) * toX, t + (b - t) * fromY, t + (b - t) * toY)
    end
    tex:ClearAllPoints()
    tex:SetPoint("TOPLEFT", ns.fx, "TOPLEFT", ax, -ay)
    tex:SetWidth(bx - ax)
    tex:SetHeight(by - ay)
    tex:Show()
end

local function dustAlpha(spec, t)
    if t < spec.rise then return spec.peak * t / spec.rise end
    if t < spec.fade then return spec.peak end
    return spec.peak * (spec.period - t) / (spec.period - spec.fade)
end

local function stepAmbient(fx, elapsed)
    fx.clock = fx.clock + elapsed
    local regionW, regionH = ns.WIDTH, artHeight()
    local shift = (fx.clock % CLOUD_PERIOD) / CLOUD_PERIOD * regionW
    local clouds = addon.atlasinfo["talents-animations-clouds"]
    clipLayer(fx.clouds[1], -shift, 0, regionW, regionH, regionW, regionH, clouds)
    clipLayer(fx.clouds[2], regionW - shift, 0, regionW, regionH, regionW, regionH, clouds)

    local dust = addon.atlasinfo["talents-animations-particles"]
    for index, spec in ipairs(DUST) do
        local t = fx.clock % spec.period
        local centreX = regionW / 2 + spec.lead - spec.drift * t / spec.period
        local layer = fx.dust[index]
        clipLayer(layer, centreX - spec.w / 2, (regionH - spec.h) / 2, spec.w, spec.h,
            regionW, regionH, dust, spec.flip)
        layer:SetAlpha(dustAlpha(spec, t))
    end
end

local function buildAmbient(win, level)
    local fx = CreateFrame("Frame", nil, win)
    fx:SetFrameLevel(level)
    fx:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -ns.ART_TOP)
    fx:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, ns.FOOTER_H)
    fx.clock = 0
    fx.clouds, fx.dust = {}, {}
    local cloudFile = addon.atlasinfo["talents-animations-clouds"][1]
    local dustFile = addon.atlasinfo["talents-animations-particles"][1]
    for index = 1, 2 do
        local cloud = fx:CreateTexture(nil, "BORDER", nil, 1)
        cloud:SetTexture(cloudFile)
        cloud:SetBlendMode("ADD")
        cloud:SetAlpha(0.05)
        fx.clouds[index] = cloud
        local mote = fx:CreateTexture(nil, "BORDER", nil, 2)
        mote:SetTexture(dustFile)
        mote:SetBlendMode("ADD")
        fx.dust[index] = mote
    end
    fx:SetScript("OnUpdate", stepAmbient)
    ns.fx = fx
end

-- Scale and placement -----------------------------------------------------------------------------

function ns.ApplyScale()
    local win = ns.win
    if not win then return end
    local wanted = tonumber(ns.Profile().scale) or 1
    wanted = min(1.5, max(0.5, wanted))
    local roomW = (UIParent:GetWidth() - 16) / ns.WIDTH
    local roomH = (UIParent:GetHeight() - 16) / (win:GetHeight() + ns.TAB_ROW)
    local scale = max(0.05, min(wanted, roomW, roomH))
    local before = win:GetScale()

    if ns.moved then
        local top, centreX = win:GetTop(), win:GetCenter()
        local oldEff = win:GetEffectiveScale()
        win:SetScale(scale)
        if top and centreX then
            local eff = win:GetEffectiveScale()
            win:ClearAllPoints()
            win:SetPoint("TOP", UIParent, "BOTTOMLEFT", centreX * oldEff / eff, top * oldEff / eff)
        end
    else
        win:SetScale(scale)
        win:ClearAllPoints()
        -- Half the tab row, in the window's own units, so window plus tabs stay centred at any scale.
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 17)
    end

    if math.abs(before - scale) > 0.0001 then ns.Call("PlaceCatcher") end
end

TM.ApplyScale = function()
    if ns.win then ns.ApplyScale() end
end

function ns.SetDepth(depth)
    if depth == ns.depth then return end
    ns.depth = depth
    local win = ns.win
    if not win then return end
    win:SetHeight(ns.WindowHeight(depth))
    ns.Call("LayoutTrees")
    if win:IsShown() then ns.ApplyScale() end
end

-- Glyph page swaps the region's content; the next repaint brings the trees and class art back.
function ns.SetGlyphPage(on)
    ns.glyphPage = on and true or false
    if not ns.win then return end
    if ns.glyphPage then
        ns.viewGroup = ns.ActiveGroup()
        ns.Call("HideTrees")
        ns.classArt:Hide()
        ns.petArt:Hide()
        ns.fx:Hide()
        ns.glyphArt:Show()
        ns.Call("ShowGlyphRoot")
    else
        ns.fx:Show()
        ns.glyphArt:Hide()
        ns.Call("HideGlyphRoot")
    end
end

-- Show and hide -----------------------------------------------------------------------------------

local function onShow()
    ns.savedPreview = GetCVar("previewTalents")
    SetCVar("previewTalents", "1")
    ns.Repaint()
    ns.Call("OrbWindowShown")
    ns.ApplyScale()
    ns.Call("StartSheen")
    PlaySound("TalentScreenOpen")
    if TalentMicroButton then SetButtonPulse(TalentMicroButton, 0, 1) end
    UpdateMicroButtons()
end

local function onHide()
    ns.Call("StopSheen")
    PlaySound("TalentScreenClose")
    UpdateMicroButtons()
    if ns.edit then ns.Call("ExitEditor") end
    wipe(ns.undo)
    ResetGroupPreviewTalentPoints(false, ns.ActiveGroup())
    if ns.PetHasTalents() then
        ResetGroupPreviewTalentPoints(true, GetActiveTalentGroup(false, true) or 1)
    end
    if ns.savedPreview ~= nil then
        SetCVar("previewTalents", ns.savedPreview)
        ns.savedPreview = nil
    end
    ns.Call("LeaveInspect")
    if not InCombatLockdown() then ns.Call("HideCatcher") end
    if addon.Menu then addon.Menu.Close() end
end

local function onDragStart(win)
    ns.dragging = true
    if not InCombatLockdown() then ns.Call("HideCatcher") end
    win:StartMoving()
end

local function onDragStop(win)
    win:StopMovingOrSizing()
    -- Named movable frames land in layout-local.txt otherwise; the position is session-only.
    win:SetUserPlaced(false)
    ns.dragging = false
    ns.moved = true
    ns.Call("PlaceCatcher")
end

local function onMouseDown()
    addon:After(0, function() ns.Call("PlaceCatcher") end)
end

-- Construction ------------------------------------------------------------------------------------

local function footerHalf(footer, atlas, left, right, bottom)
    local entry = addon.atlasinfo[atlas]
    local half = footer:CreateTexture(nil, "BORDER")
    half:SetTexture(entry[1])
    half:SetTexCoord(left or entry[4], right or entry[5], entry[6], bottom)
    return half
end

local function buildChrome(win, level)
    local chrome = CreateFrame("Frame", nil, win)
    chrome:SetAllPoints(win)
    chrome:SetFrameLevel(level)
    local layout = NineSliceUtils and NineSliceUtils.GetLayout("PortraitFrameTemplate")
    if layout then NineSliceUtils.ApplyLayout(chrome, layout) end

    local title = chrome:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", chrome, "TOPLEFT", 58, -6)
    title:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -24, -6)
    title:SetJustifyH("CENTER")
    title:SetText(TALENTS)
    ns.title = title

    ns.portrait = chrome:CreateTexture(nil, "ARTWORK")
    ns.chrome = chrome
end

local function buildFooter(win, level)
    local footer = CreateFrame("Frame", nil, win)
    footer:SetFrameLevel(level)
    footer:SetHeight(ns.FOOTER_H)
    footer:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, 0)

    -- One 1612-px strip would need a 2048-wide texture, which crashes the client; hence two halves.
    local west = footerHalf(footer, "talents-background-bottombar-left", 0.005740792, nil, 0.562353516)
    west:SetPoint("TOPLEFT", win, "BOTTOMLEFT", 2, ns.FOOTER_H)
    west:SetPoint("BOTTOMRIGHT", win, "BOTTOM", 0, 3)
    local east = footerHalf(footer, "talents-background-bottombar-right", nil, 0.790157645, 0.734228516)
    east:SetPoint("TOPLEFT", win, "BOTTOM", 0, ns.FOOTER_H)
    east:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 3)
    ns.footer = footer
end

local function buildCloseButton(win, level)
    local close = CreateFrame("Button", "DragonUI_TalentFrameCloseButton", win, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", win, "TOPRIGHT", 1, 0)
    close:SetFrameLevel(level)
    close:SetScript("OnClick", function() win:Hide() end)
    local CP = addon.CharacterPanel
    if CP and CP.ModernizeCloseButton then CP.ModernizeCloseButton(close, win, 1, 0) end
end

local function regionTexture(win)
    local tex = win:CreateTexture(nil, "BORDER")
    tex:SetPoint("TOPLEFT", win, "TOPLEFT", 0, -ns.ART_TOP)
    tex:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", 0, ns.FOOTER_H)
    return tex
end

function ns.BuildWindow()
    if ns.win then return ns.win end
    local win = CreateFrame("Frame", "DragonUI_TalentFrame", UIParent)
    ns.win = win
    win:Hide()
    win:SetSize(ns.WIDTH, ns.WindowHeight(ns.depth))
    win:SetFrameStrata("HIGH")
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    win:SetClampRectInsets(0, 0, 0, -ns.TAB_ROW)
    win:RegisterForDrag("LeftButton")
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 17)
    tinsert(UISpecialFrames, win:GetName())

    local base = win:GetFrameLevel()

    local fill = win:CreateTexture(nil, "BACKGROUND", nil, -8)
    fill:SetTexture(0.04, 0.04, 0.05, 1)
    fill:SetPoint("TOPLEFT", win, "TOPLEFT", 2, -21)
    fill:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -2, 2)

    ns.classArt = regionTexture(win)
    ns.petArt = regionTexture(win)
    ns.petArt:Hide()
    ns.glyphArt = regionTexture(win)
    ns.glyphArt:Hide()

    buildAmbient(win, base + 1)
    ns.Call("BuildTrees", win, base + 3)
    buildFooter(win, base + 6)
    buildChrome(win, base + 8)

    local tabHolder = CreateFrame("Frame", nil, win)
    tabHolder:SetAllPoints(win)
    tabHolder:SetFrameLevel(base + 8)
    ns.tabHolder = tabHolder

    buildCloseButton(win, base + 9)
    ns.Call("BuildFooterControls", ns.footer)
    ns.Call("BuildTabs", tabHolder)
    ns.Call("BuildSpecCog", ns.footer)
    ns.Call("BuildOrb", win, base + 9)

    win:SetScript("OnShow", onShow)
    win:SetScript("OnHide", onHide)
    win:SetScript("OnDragStart", onDragStart)
    win:SetScript("OnDragStop", onDragStop)
    win:SetScript("OnMouseDown", onMouseDown)

    ns.SetPortraitClass(ns.PlayerClass())
    ns.viewGroup = ns.ActiveGroup()
    ns.ApplyScale()
    return win
end
