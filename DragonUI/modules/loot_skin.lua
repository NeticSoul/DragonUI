-- =============================================================================
-- DRAGONUI LOOT WINDOW MODULE
-- Copyright (c) 2026 Neticsoul and DragonUI contributors. Released under the MIT
-- License; see LICENSE at the repository root.
--
-- Rewritten from a base module contributed by PentSec, with thanks.
-- =============================================================================

local addon = select(2, ...)
local L = addon.L

local _G = _G
local ipairs = ipairs
local pairs = pairs
local unpack = unpack
local wipe = wipe
local tremove = tremove
local max = math.max
local min = math.min
local abs = math.abs
local GetTime = GetTime

local assets = addon._dir
local textures = {
    background = assets .. "UI\\ui-background-rock",
    close = assets .. "UI\\redbutton2x",
    slot = assets .. "Bags\\bagsitemslot2x",
    pushed = assets .. "UI\\ui-quickslot-depress",
    highlight = assets .. "UI\\buttonhilight-square",
    slotBorder = assets .. "UI\\ui-quickslot2",
}

-- Retail has no pages: LootFrame is a ScrollBox. Numbers below are off its own LootFrame.xml.
local FRAME_WIDTH = 220
local SCROLLBAR_WIDTH = 16
local PANEL_MAX_HEIGHT = 290
-- 88 is where the rails between the 75px top and 32px bottom corners run out of height to fill.
local FRAME_MIN_HEIGHT = 92
local VIEW_LEFT = 4
local VIEW_TOP = 22
-- Clips this much lower than retail: at 22 the rows draw over the trim on their way out.
local CLIP_TRIM = 1
local VIEW_BOTTOM = 4
local VIEW_WIDTH = 214
local LIST_PAD = 6
local ROW_HEIGHT = 46
local ROW_SPACING = 2
local ROW_PITCH = ROW_HEIGHT + ROW_SPACING
local ROW_WIDTH = VIEW_WIDTH - LIST_PAD * 2
-- Centred, unlike retail's 10/8. Off the bar-less width so rows hold still when the bar appears.
local ROW_INSET = (FRAME_WIDTH - ROW_WIDTH) / 2
local CANVAS_INSET = ROW_INSET - VIEW_LEFT
-- The viewport is wider than a row, so its right margin is not the left one mirrored.
local CANVAS_INSET_RIGHT = VIEW_WIDTH - CANVAS_INSET - ROW_WIDTH
-- ScrollingFlatPanelMixin:Resize adds 26 for the viewport's anchors and 20 of slack on top.
local PANEL_CHROME = VIEW_TOP + VIEW_BOTTOM + 20
-- Blizzard drops the frame 95 below the cursor, which lands it on the second row; centre the first.
local CURSOR_DROP = VIEW_TOP + LIST_PAD + ROW_HEIGHT / 2
local ICON_X, ICON_Y, ICON_SIZE = 5, 4, 37
local NAME_X, NAME_Y, NAME_WIDTH, NAME_HEIGHT = 8, -8, 150, 30
local COIN_X, COIN_WIDTH, COIN_HEIGHT = 8, 93, 38
local TAG_WIDTH, TAG_HEIGHT = 100, 13
local TAG_TEXT_X, TAG_TEXT_Y = -4, -2
-- SetShadowsScale(0.2) scales the whole Shadows frame, so retail's 150px of art lands at 30 here.
local SHADOW_HEIGHT = 30
-- Covers the rounding hairline at a stretched aspect without climbing onto the trim above it.
local SHADOW_BLEED = 1
-- ui-quickslot2 paints only 12..50 of its 64; full size, the margin fakes a scroll range.
local RING_SIZE = 39
local RING_COORD_MIN, RING_COORD_MAX = 12 / 64, 51 / 64
local VANILLA_ROWS = _G.LOOTFRAME_NUMBUTTONS or 4

-- Retail LootFrame.xml SlideOutRightAnim: 100px over 0.3s, alpha 1->0 over 0.2s after a 0.1s hold.
local EXIT_DISTANCE = 100
local EXIT_DURATION = 0.3
local EXIT_FADE_DELAY = 0.1
local EXIT_FADE_DURATION = 0.2
-- 3.3.5a clears every slot in one packet, so retail's server-paced cascade is faked here.
local EXIT_STAGGER = 0.07
-- Shape of retail's ScrollingFlatPanel HideAnim, minus the translation.
local CLOSE_FADE_DURATION = 0.1

local LootSkinModule = {
    initialized = false,
    applied = false,
    hooksInstalled = false,
}

if addon.RegisterModule then
    addon:RegisterModule(
        "loot_skin",
        LootSkinModule,
        L["Loot Window"],
        L["Retail-style skin for the Blizzard loot window"],
        { loadOnce = true }
    )
end

local function IsActive()
    return LootSkinModule.applied and addon:IsModuleEnabled("loot_skin")
end

-- ============================================================================
-- BLIZZARD STATE
-- ============================================================================

local originals = {}
local frameOriginal

local function Remember(object)
    if not object or originals[object] then
        return object
    end

    local snapshot = {}
    if object.GetNumPoints then
        snapshot.points = {}
        for i = 1, object:GetNumPoints() do
            -- relativeTo is nil for parent-anchored regions, so unpack needs the stored arity.
            local point = { object:GetPoint(i) }
            point.n = select("#", object:GetPoint(i))
            snapshot.points[i] = point
        end
    end
    if object.GetTexture then
        snapshot.texture = object:GetTexture()
    end
    if object.GetDrawLayer then
        snapshot.layer = object:GetDrawLayer()
    end
    if object.GetHitRectInsets then
        snapshot.hitRect = { object:GetHitRectInsets() }
    end

    originals[object] = snapshot
    return object
end

-- Not in Remember: a region with neither size nor anchors fills its parent, and a size pins it.
local function Resize(object, width, height)
    local snapshot = originals[Remember(object)]
    if not snapshot.sized then
        snapshot.sized = true
        snapshot.width, snapshot.height = object:GetWidth(), object:GetHeight()
    end
    object:SetWidth(width)
    object:SetHeight(height)
end

local function Reparent(object, parent)
    local snapshot = originals[Remember(object)]
    if not snapshot.reparented then
        snapshot.reparented = true
        snapshot.parent = object:GetParent()
    end
    object:SetParent(parent)
end

-- Only what we hid: re-Show()ing a button's state textures strands a pushed overlay on screen.
local function HideVanilla(region)
    if region then
        originals[Remember(region)].hidden = region:IsShown()
        region:Hide()
    end
end

local function RestoreRemembered()
    for object, snapshot in pairs(originals) do
        -- Before the anchors: points taken against the skin mean nothing under the original parent.
        if snapshot.reparented then
            object:SetParent(snapshot.parent)
        end
        if snapshot.points and #snapshot.points > 0 then
            object:ClearAllPoints()
            for _, point in ipairs(snapshot.points) do
                object:SetPoint(unpack(point, 1, point.n))
            end
        end
        if object.SetTexture then
            object:SetTexture(snapshot.texture)
            object:SetTexCoord(0, 1, 0, 1)
        end
        if snapshot.layer and object.SetDrawLayer then
            object:SetDrawLayer(snapshot.layer)
        end
        if snapshot.sized then
            object:SetWidth(snapshot.width)
            object:SetHeight(snapshot.height)
        end
        if snapshot.hitRect then
            object:SetHitRectInsets(unpack(snapshot.hitRect))
        end
        if snapshot.hidden then
            object:Show()
        end
        originals[object] = nil
    end
end

-- ============================================================================
-- TWEENS (no AnimationGroup API on 3.3.5a)
-- ============================================================================

local tweens = {}
local driver

local function StepTweens()
    local now = GetTime()
    for i = #tweens, 1, -1 do
        local tween = tweens[i]
        local progress = (now - tween.start - tween.delay) / tween.duration
        if progress >= 1 then
            tremove(tweens, i)
            tween.step(1)
            if tween.finish then
                tween.finish()
            end
        elseif progress > 0 then
            tween.step(progress)
        end
    end
    if #tweens == 0 then
        driver:SetScript("OnUpdate", nil)
    end
end

local function Tween(delay, duration, step, finish)
    tweens[#tweens + 1] = { start = GetTime(), delay = delay, duration = duration, step = step, finish = finish }
    driver = driver or CreateFrame("Frame")
    driver:SetScript("OnUpdate", StepTweens)
end

-- ============================================================================
-- PANEL
-- ============================================================================

-- Off LootFrame so the skin outlives LOOT_CLOSED, which would cut the fly-outs off mid-flight.
local panel, title, clip, canvas, shades, shadowTop, shadowBottom
local cards = {}
local rowCount = 0
local extraRows = {}
-- Our own prefix: the globals exist for $parent lookups but Blizzard never reads them, which taints.
local ROW_PREFIX = "DragonUILootRow"
-- Read fresh: Blizzard fills its buttons before our post-hook, so a cached count is a corpse late.
local function BlizzardRows()
    local items = _G.LootFrame and _G.LootFrame.numLootItems or 0
    if items > VANILLA_ROWS then
        return VANILLA_ROWS - 1
    end
    return VANILLA_ROWS
end

-- Memoised: UpdateViewport walks every row each frame while the wheel glides.
local blizzNames, ownNames = {}, {}

local function RowName(index)
    if index <= BlizzardRows() then
        local name = blizzNames[index]
        if not name then
            name = "LootButton" .. index
            blizzNames[index] = name
        end
        return name
    end
    local name = ownNames[index]
    if not name then
        name = ROW_PREFIX .. index
        ownNames[index] = name
    end
    return name
end

local function RowButton(index)
    return _G[RowName(index)]
end

local function RowRegion(index, suffix)
    return _G[RowName(index) .. suffix]
end

local function ScrollBar()
    return clip and _G[clip:GetName() .. "ScrollBar"]
end

local hitTop, hitBottom = {}, {}

-- A ScrollFrame clips drawing but not the mouse, so off-screen rows need their hit rect clamped.
local function UpdateViewport(viewHeight)
    if not shades then
        return
    end

    local height = viewHeight or clip:GetHeight()
    local scroll = clip:GetVerticalScroll()
    local range = max(0, canvas:GetHeight() - height)
    -- Faded by how much is actually hidden behind it, so a hair of scroll no longer snaps it on.
    shadowTop:SetAlpha(min(1, scroll / SHADOW_HEIGHT))
    shadowBottom:SetAlpha(min(1, max(0, range - scroll) / SHADOW_HEIGHT))

    for index = 1, rowCount do
        local button = RowButton(index)
        if button then
            local top = LIST_PAD - CLIP_TRIM + (index - 1) * ROW_PITCH - scroll
            local bottom = top + ROW_HEIGHT
            local shownTop = top > 0 and top or 0
            local shownBottom = bottom < height and bottom or height
            -- Only on a real change: re-asserting under the cursor re-runs mouse detection every frame.
            if shownBottom - shownTop < 1 then
                if button:IsMouseEnabled() then
                    button:EnableMouse(false)
                end
            else
                if not button:IsMouseEnabled() then
                    button:EnableMouse(true)
                end
                local insetTop = shownTop - top - ICON_Y
                local insetBottom = ICON_Y + ICON_SIZE - (shownBottom - top)
                if hitTop[index] ~= insetTop or hitBottom[index] ~= insetBottom then
                    hitTop[index], hitBottom[index] = insetTop, insetBottom
                    button:SetHitRectInsets(
                        -ICON_X,
                        -(ROW_WIDTH - ICON_X - ICON_SIZE),
                        insetTop,
                        insetBottom
                    )
                end
            end
        end
    end
end

-- Eased toward a target; the driver only runs while moving, and a new notch retargets it.
local SCROLL_RATE = 14
local scrollTarget, scrollWrote
local scroller = CreateFrame("Frame")
scroller:Hide()

local function StopScroll()
    scroller:Hide()
    scrollTarget, scrollWrote = nil, nil
end

scroller:SetScript("OnUpdate", function(self, elapsed)
    local current = clip:GetVerticalScroll()
    -- Someone else moved it: the scrollbar drag or a relayout. Theirs wins.
    if scrollWrote and abs(current - scrollWrote) > 0.5 then
        StopScroll()
        return
    end

    local range = clip:GetVerticalScrollRange()
    local target = min(scrollTarget or 0, range)
    local diff = target - current
    if abs(diff) < 0.5 then
        clip:SetVerticalScroll(target)
        StopScroll()
        return
    end

    local value = current + diff * min(1, elapsed * SCROLL_RATE)
    scrollWrote = value
    clip:SetVerticalScroll(value)
end)

local function WheelScroll(self, delta)
    local range = self:GetVerticalScrollRange()
    if range <= 0 then
        return
    end
    local value = (scrollTarget or self:GetVerticalScroll()) - delta * ROW_PITCH
    scrollTarget = value < 0 and 0 or (value > range and range or value)
    scrollWrote = nil
    scroller:Show()
end

-- set_atlas would stamp the unflipped rect straight back over a SetTexCoord, so read it by hand.
local function SetFlippedAtlas(texture, name)
    local info = addon.atlasinfo and addon.atlasinfo[name]
    if not info then
        return
    end
    texture:SetTexture(info[1])
    texture:SetTexCoord(info[4], info[5], info[7], info[6])
end

local function BuildPanel(frame)
    if panel then
        return
    end

    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("HIGH")
    panel:SetAllPoints(frame)
    panel:Hide()

    -- The panel covers LootFrame, so it has to take over the drag its TitleRegion used to handle.
    panel:EnableMouse(true)
    panel:RegisterForDrag("LeftButton")
    panel:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    panel:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
    end)

    NineSliceUtils.ApplyLayout(panel, NineSliceUtils.GetLayout("NoPortraitFrameTemplate"))

    local background = panel:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(textures.background)
    background:SetAlpha(0.8)
    background:SetPoint("TOPLEFT", panel, "TOPLEFT", 2, -20)
    background:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -2, 2)

    -- Created after the nineslice so it wins the OVERLAY tie-break against the rails it sits on.
    title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetText(ITEMS)
    title:SetPoint("TOP", panel, "TOP", 0, -5)

    -- No SetClipsChildren on 3.3.5a; a ScrollFrame is the only thing that clips drawing at all.
    clip = CreateFrame("ScrollFrame", "DragonUILootScrollFrame", panel, "UIPanelScrollFrameTemplate")
    clip:SetPoint("TOPLEFT", panel, "TOPLEFT", VIEW_LEFT, -(VIEW_TOP + CLIP_TRIM))
    clip:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", VIEW_LEFT, VIEW_BOTTOM)
    clip:SetWidth(VIEW_WIDTH)
    clip.scrollBarHideable = true
    clip:EnableMouseWheel(true)
    -- Blizzard's wheel step is half the bar's height; retail's ScrollBox pans one row per notch.
    clip:SetScript("OnMouseWheel", WheelScroll)
    -- Wrapped: both scripts hand their handler arguments the viewport height slot would swallow.
    clip:HookScript("OnVerticalScroll", function()
        UpdateViewport()
    end)
    clip:HookScript("OnScrollRangeChanged", function()
        UpdateViewport()
    end)

    canvas = CreateFrame("Frame", nil, clip)
    canvas:SetWidth(VIEW_WIDTH)
    canvas:SetHeight(1)
    clip:SetScrollChild(canvas)

    -- Outside the ScrollFrame so the fade stays pinned to the viewport instead of scrolling away.
    shades = CreateFrame("Frame", nil, panel)
    shades:SetPoint("TOPLEFT", clip, "TOPLEFT")
    shades:SetPoint("BOTTOMRIGHT", clip, "BOTTOMRIGHT")

    shadowTop = shades:CreateTexture(nil, "ARTWORK")
    SetFlippedAtlas(shadowTop, "_looting_itemcard_shadow-center")
    shadowTop:SetHeight(SHADOW_HEIGHT + SHADOW_BLEED)
    shadowTop:SetPoint("TOPLEFT", shades, "TOPLEFT", CANVAS_INSET, SHADOW_BLEED)
    shadowTop:SetPoint("TOPRIGHT", shades, "TOPRIGHT", -CANVAS_INSET_RIGHT, SHADOW_BLEED)
    shadowTop:SetAlpha(0)

    shadowBottom = shades:CreateTexture(nil, "ARTWORK")
    addon:SafeSetAtlas(shadowBottom, "_looting_itemcard_shadow-center", false)
    shadowBottom:SetHeight(SHADOW_HEIGHT + SHADOW_BLEED)
    shadowBottom:SetPoint("BOTTOMLEFT", shades, "BOTTOMLEFT", CANVAS_INSET, -SHADOW_BLEED)
    shadowBottom:SetPoint("BOTTOMRIGHT", shades, "BOTTOMRIGHT", -CANVAS_INSET_RIGHT, -SHADOW_BLEED)
    shadowBottom:SetAlpha(0)

    local bar = ScrollBar()
    if bar then
        bar:Hide()
    end
end

-- Above LootFrame, not below: rows in the canvas would never see a click under an enabled frame.
local function SyncPanelLevel(frame)
    local level = frame:GetFrameLevel() + 1
    panel:SetFrameLevel(level)
    clip:SetFrameLevel(level + 1)
    canvas:SetFrameLevel(level + 2)
    for i = 1, rowCount do
        local card = cards[i]
        if card then
            card:SetFrameLevel(level + 3)
            local blizz = i <= VANILLA_ROWS and _G["LootButton" .. i] or nil
            if blizz then
                blizz:SetFrameLevel(level + 4)
            end
            if extraRows[i] then
                extraRows[i]:SetFrameLevel(level + 4)
            end
        end
    end
    shades:SetFrameLevel(level + 5)

    -- 3.3.5a leaves children put when a parent's level moves, so the reskinned bar needs re-seating.
    local bar = ScrollBar()
    if bar then
        bar:SetFrameLevel(level + 6)
        if bar._duiGrabber then
            bar._duiGrabber:SetFrameLevel(level + 7)
        end
    end
end

local function StripVanillaArt(frame)
    for _, region in ipairs({ frame:GetRegions() }) do
        local kind = region:GetObjectType()
        if kind == "Texture" then
            local path = region:GetTexture()
            if type(path) == "string" and path:lower():find("ui%-lootpanel") then
                HideVanilla(region)
            end
        elseif kind == "FontString" and region:GetText() == ITEMS then
            HideVanilla(region)
        end
    end

    -- Retail's loot panel carries no portrait, and the chrome has no cutout for one.
    HideVanilla(_G.LootFramePortraitOverlay)
end

-- ============================================================================
-- ROW CARDS
-- ============================================================================

local function CreateCard(parent)
    local card = CreateFrame("Frame", nil, parent)
    card:SetWidth(ROW_WIDTH)
    card:SetHeight(ROW_HEIGHT)

    card.bg = card:CreateTexture(nil, "BACKGROUND")
    addon:SafeSetAtlas(card.bg, "looting_itemcard_bg", false)
    card.bg:SetAllPoints(card)

    -- Retail keeps the tag on the background layer too; creation order is what puts it on top.
    card.tag = card:CreateTexture(nil, "BACKGROUND")
    addon:SafeSetAtlas(card.tag, "looting_raritytag_frame", false)
    card.tag:SetWidth(TAG_WIDTH)
    card.tag:SetHeight(TAG_HEIGHT)
    card.tag:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)

    card.border = card:CreateTexture(nil, "BORDER")
    addon:SafeSetAtlas(card.border, "looting_itemcard_stroke_normal", false)
    card.border:SetAllPoints(card)

    -- FRIZQT at 8, which is what retail's GameFontWhiteTiny2 resolves to.
    card.rarity = card:CreateFontString(nil, "ARTWORK", "GameFontWhiteTiny")
    card.rarity:SetFont(card.rarity:GetFont(), 8)
    card.rarity:SetPoint("TOPRIGHT", card, "TOPRIGHT", TAG_TEXT_X, TAG_TEXT_Y)
    card.rarity:SetJustifyH("RIGHT")

    card.hover = card:CreateTexture(nil, "OVERLAY")
    addon:SafeSetAtlas(card.hover, "looting_itemcard_stroke_clickstate", false)
    card.hover:SetAllPoints(card)
    card.hover:SetBlendMode("ADD")
    card.hover:SetAlpha(0.7)
    card.hover:Hide()

    card.pushed = card:CreateTexture(nil, "OVERLAY")
    addon:SafeSetAtlas(card.pushed, "looting_itemcard_stroke_clickstate", false)
    card.pushed:SetAllPoints(card)
    card.pushed:SetBlendMode("ADD")
    card.pushed:Hide()

    card:Hide()
    return card
end

-- Retail's money row opts out of quality colouring entirely, so coins keep the art untinted.
local function PaintCard(card, quality, isCoin)
    local color = not isCoin and quality and ITEM_QUALITY_COLORS[quality]
    if color then
        card.bg:SetVertexColor(color.r, color.g, color.b)
    else
        card.bg:SetVertexColor(1, 1, 1)
    end

    local rarity = not isCoin and quality and _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if rarity then
        card.rarity:SetText(rarity)
        card.rarity:Show()
        card.tag:Show()
    else
        card.rarity:Hide()
        card.tag:Hide()
    end
end

-- ============================================================================
-- EXIT ANIMATION
-- ============================================================================

local flying = 0
local closePending = false

local function RowTop(index)
    return -(LIST_PAD + (index - 1) * ROW_PITCH)
end

local function HidePanel()
    panel:Hide()
    panel:SetAlpha(1)
    closePending = false
end

local function ResetAnimations()
    wipe(tweens)
    if driver then
        driver:SetScript("OnUpdate", nil)
    end
    for _, card in ipairs(cards) do
        card:SetAlpha(1)
        card.hover:Hide()
        card.pushed:Hide()
    end
    flying = 0
    closePending = false
    panel:SetAlpha(1)
end

local function OnExitFinished(card, button)
    card:Hide()
    card:SetAlpha(1)
    if button then
        button:Hide()
    end
    flying = flying - 1
    if flying == 0 and closePending then
        Tween(0, CLOSE_FADE_DURATION, function(progress)
            panel:SetAlpha(1 - progress)
        end, HidePanel)
    end
end

-- The row itself flies, never a copy, and rides in the canvas so the slide gets clipped.
local function PlayExit(index)
    local card, button = cards[index], RowButton(index)
    if not card then
        return
    end
    local top = RowTop(index) + CLIP_TRIM

    card:SetParent(canvas)
    card:ClearAllPoints()
    card:SetPoint("TOPLEFT", canvas, "TOPLEFT", CANVAS_INSET, top)
    card:SetAlpha(1)
    card:Show()
    -- Blizzard hid it the moment the slot cleared; it has to come back to leave with its row.
    if button then
        button:Show()
    end
    flying = flying + 1

    Tween((index - 1) * EXIT_STAGGER, EXIT_DURATION, function(progress)
        card:SetPoint("TOPLEFT", canvas, "TOPLEFT", CANVAS_INSET + EXIT_DISTANCE * progress * progress, top)
        local fade = (progress * EXIT_DURATION - EXIT_FADE_DELAY) / EXIT_FADE_DURATION
        card:SetAlpha(fade > 0 and 1 - fade * fade or 1)
    end, function()
        OnExitFinished(card, button)
    end)
end

-- ============================================================================
-- LOOT FRAME
-- ============================================================================

local slotCache = {}
local isAutoLoot = false

local function SkinCloseButton()
    local button = _G.LootCloseButton
    if not button then
        return
    end

    Reparent(button, panel)
    Resize(button, 24, 24)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 1, 0)

    local normal = button:GetNormalTexture()
    if normal then
        Remember(normal):SetTexture(textures.close)
        normal:SetTexCoord(0.152344, 0.292969, 0.0078125, 0.304688)
    end

    local pushed = button:GetPushedTexture()
    if pushed then
        Remember(pushed):SetTexture(textures.close)
        pushed:SetTexCoord(0.152344, 0.292969, 0.632812, 0.929688)
    end

    local highlight = button:GetHighlightTexture()
    if highlight then
        Remember(highlight):SetTexture(textures.close)
        highlight:SetTexCoord(0.449219, 0.589844, 0.0078125, 0.304688)
    end
end

local function SkinItemButton(button, name)
    if not button then
        return
    end

    HideVanilla(_G[name .. "NameFrame"])

    -- Vanilla's normal texture IS the 64x64 ring; a flat plate keeps quality tint off its locked red.
    local normal = button:GetNormalTexture()
    if normal then
        Remember(normal):SetTexture(textures.slot)
        Resize(normal, ICON_SIZE, ICON_SIZE)
        normal:ClearAllPoints()
        normal:SetPoint("CENTER", button, "CENTER")
        normal:SetDrawLayer("BACKGROUND")
    end

    local pushed = button:GetPushedTexture()
    if pushed then
        Remember(pushed):SetTexture(textures.pushed)
    end

    local highlight = button:GetHighlightTexture()
    if highlight then
        Remember(highlight):SetTexture(textures.highlight)
    end

    -- 3.3.5a's SetDrawLayer takes no sublevel, so the ring has to be created after the icon.
    local ring = button._dragonuiSlotBorder
    if not ring then
        ring = button:CreateTexture(nil, "BORDER")
        button._dragonuiSlotBorder = ring
    end
    ring:SetTexture(textures.slotBorder)
    ring:SetTexCoord(RING_COORD_MIN, RING_COORD_MAX, RING_COORD_MIN, RING_COORD_MAX)
    ring:SetWidth(RING_SIZE)
    ring:SetHeight(RING_SIZE)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", button, "CENTER", -0.5, -0.5)
    ring:Show()
end

-- Either button can serve a row depending on the item count, so both get dressed onto the card.
local function DressButton(button, name, card, index)
    if not button then
        return
    end

    SkinItemButton(button, name)
    Reparent(button, card)
    Remember(button):ClearAllPoints()
    button:SetPoint("TOPLEFT", card, "TOPLEFT", ICON_X, -ICON_Y)
    -- The hit rect is UpdateViewport's alone, so it can cache it and stop rewriting it.
    hitTop[index], hitBottom[index] = nil, nil

    if not button._dragonuiRowHooks then
        button._dragonuiRowHooks = true
        button:HookScript("OnEnter", function()
            if IsActive() then
                card.hover:Show()
            end
        end)
        button:HookScript("OnLeave", function()
            if IsActive() then
                card.hover:Hide()
                card.pushed:Hide()
            end
        end)
        button:HookScript("OnMouseDown", function()
            if IsActive() then
                card.pushed:Show()
            end
        end)
        button:HookScript("OnMouseUp", function()
            if IsActive() then
                card.pushed:Hide()
            end
        end)
    end
end

local function BuildRow(index)
    local card = cards[index]
    if not card then
        card = CreateCard(panel)
        cards[index] = card
    end

    if index <= VANILLA_ROWS then
        DressButton(_G["LootButton" .. index], "LootButton" .. index, card, index)
    end
    if index >= VANILLA_ROWS then
        DressButton(extraRows[index], ROW_PREFIX .. index, card, index)
    end
end

-- LOOTFRAME_NUMBUTTONS stays at four: a Blizzard global an addon writes is tainted for the session.
local function EnsureRows(count)
    if count <= rowCount then
        return false
    end

    for index = rowCount + 1, count do
        if index >= VANILLA_ROWS and not extraRows[index] then
            local button = CreateFrame("Button", ROW_PREFIX .. index, _G.LootFrame, "LootButtonTemplate")
            button:SetID(index)
            extraRows[index] = button
        end
        BuildRow(index)
    end
    rowCount = count
    return true
end

-- Blizzard's hook also reaches index 4, ours past four items and not filled yet; it skips those.
local function StyleRow(index, ownPass)
    if not IsActive() then
        return
    end
    if not ownPass and index > BlizzardRows() then
        return
    end

    local button, card = RowButton(index), cards[index]
    if not (button and card) then
        return
    end

    if not button:IsShown() then
        card:Hide()
        return
    end

    local slot, quality = button.slot, button.quality
    local isCoin = slot and LootSlotIsCoin(slot)
    local color = quality and ITEM_QUALITY_COLORS[quality]

    PaintCard(card, quality, isCoin)
    card:Show()

    local ring = button._dragonuiSlotBorder
    if ring then
        ring:SetVertexColor(color and color.r or 0.6, color and color.g or 0.6, color and color.b or 0.6)
    end

    local text = RowRegion(index, "Text")
    if text then
        -- Snapshotted before the anchors go: Remember would otherwise record an empty point list.
        Remember(text):ClearAllPoints()
        if isCoin then
            Resize(text, COIN_WIDTH, COIN_HEIGHT)
            text:SetJustifyV("MIDDLE")
            text:SetPoint("LEFT", button, "RIGHT", COIN_X, 0)
        else
            Resize(text, NAME_WIDTH, NAME_HEIGHT)
            text:SetJustifyV("TOP")
            text:SetPoint("TOPLEFT", button, "TOPRIGHT", NAME_X, NAME_Y)
        end
    end

    if slot then
        slotCache[slot] = index
    end
end

-- WoW sizes a scroll child from its children, so hiding a row re-anchors it and shifts the rest 1px.
local function HostRows(scrolls)
    for index = 1, rowCount do
        local card = cards[index]
        if card then
            card:SetParent(scrolls and canvas or panel)
            card:ClearAllPoints()
            if scrolls then
                card:SetPoint("TOPLEFT", canvas, "TOPLEFT", CANVAS_INSET, RowTop(index) + CLIP_TRIM)
            else
                card:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_INSET, -VIEW_TOP + RowTop(index))
            end
        end
    end
    SyncPanelLevel(_G.LootFrame)
end

local function ResizeFrame(frame)
    local rows = 0
    for index = 1, rowCount do
        local button = RowButton(index)
        if button and button:IsShown() then
            rows = index
        end
    end
    if rows < 1 then
        rows = 1
    end

    local content = rows * ROW_HEIGHT + (rows - 1) * ROW_SPACING
    canvas:SetHeight(content + LIST_PAD * 2 - CLIP_TRIM)

    local height = min(PANEL_MAX_HEIGHT, content + PANEL_CHROME)
    if height < FRAME_MIN_HEIGHT then
        height = FRAME_MIN_HEIGHT
    end

    local viewHeight = height - VIEW_TOP - VIEW_BOTTOM
    local scrolls = canvas:GetHeight() > viewHeight
    HostRows(scrolls)
    frame:SetHeight(height)
    frame:SetWidth(FRAME_WIDTH + (scrolls and SCROLLBAR_WIDTH or 0))
    StopScroll()
    clip:SetVerticalScroll(0)

    local bar = ScrollBar()
    if bar then
        if scrolls then
            bar:Show()
        else
            bar:Hide()
        end
    end

    local CP = addon.CharacterPanel
    if CP and CP.SyncScrollBarVisibility then
        CP.SyncScrollBarVisibility(clip)
    end
    -- Passed in rather than measured: the viewport is anchored to a frame resized a line ago.
    UpdateViewport(viewHeight)
end

-- Blizzard fills only its four; hiding its pager also stops LOOT_SLOT_CLEARED auto-paging.
local function UpdateOwnRows()
    local items = _G.LootFrame.numLootItems or 0
    local blizz = BlizzardRows()
    for index = VANILLA_ROWS, rowCount do
        local button = extraRows[index]
        if button then
            if index > blizz and index <= items and (LootSlotIsItem(index) or LootSlotIsCoin(index)) then
                local texture, item, quantity, quality, locked = GetLootSlotInfo(index)
                button.slot = index
                button.quality = quality
                _G[ROW_PREFIX .. index .. "IconTexture"]:SetTexture(texture)

                local text = _G[ROW_PREFIX .. index .. "Text"]
                text:SetText(item)
                local color = ITEM_QUALITY_COLORS[quality]
                if color then
                    text:SetVertexColor(color.r, color.g, color.b)
                end

                SetItemButtonTextureVertexColor(button, locked and 0.9 or 1, locked and 0 or 1, locked and 0 or 1)
                local count = _G[ROW_PREFIX .. index .. "Count"]
                if quantity and quantity > 1 then
                    count:SetText(quantity)
                    count:Show()
                else
                    count:Hide()
                end
                button:Show()
            else
                -- Cleared so a stale slot cannot reach the fly-out cache on the next corpse.
                button.slot, button.quality = nil, nil
                button:Hide()
            end
        end
    end
end

local function OnLootFrameUpdate()
    if not IsActive() then
        return
    end

    _G.LootFramePrev:Hide()
    _G.LootFrameNext:Hide()
    _G.LootFrameUpButton:Hide()
    _G.LootFrameDownButton:Hide()

    UpdateOwnRows()
    for index = VANILLA_ROWS, rowCount do
        StyleRow(index, true)
    end
    ResizeFrame(_G.LootFrame)
end

-- ============================================================================
-- EVENTS
-- ============================================================================

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if not IsActive() then
        return
    end

    if event == "LOOT_OPENED" then
        -- 3.3.5a passes autoLoot as a number, unlike retail's boolean.
        isAutoLoot = arg1 and arg1 ~= 0
        -- Blizzard already laid the window out by now, so a grown pool has to redo it.
        if EnsureRows(GetNumLootItems()) then
            SyncPanelLevel(_G.LootFrame)
            LootFrame_Update()
        end
    elseif event == "LOOT_CLOSED" then
        isAutoLoot = false
        wipe(slotCache)
    elseif event == "LOOT_SLOT_CLEARED" and _G.LootFrame:IsShown() then
        local index = slotCache[arg1]
        if not index then
            return
        end
        slotCache[arg1] = nil

        local card, button = cards[index], RowButton(index)
        card.hover:Hide()
        card.pushed:Hide()
        -- Blizzard only hides its own four here, so rows past them have to retire themselves.
        if button == extraRows[index] then
            button:Hide()
        end

        if isAutoLoot then
            PlayExit(index)
        elseif not button:IsShown() then
            -- The button is a child of the card, so hiding early would take a live row with it.
            card:Hide()
        end
    end
end)

local function InstallHooks(frame)
    if LootSkinModule.hooksInstalled then
        return
    end
    LootSkinModule.hooksInstalled = true

    hooksecurefunc("LootFrame_UpdateButton", StyleRow)
    hooksecurefunc("LootFrame_Update", OnLootFrameUpdate)

    frame:HookScript("OnShow", function(self)
        if not IsActive() then
            return
        end
        ResetAnimations()
        SyncPanelLevel(self)
        panel:Show()
    end)

    -- LootFrame_Show raises the frame after OnShow fired, leaving the panel a level short.
    hooksecurefunc("LootFrame_Show", function(self)
        if not IsActive() then
            return
        end
        if GetCVar("lootUnderMouse") == "1" and (self.numLootItems or 0) > 0 then
            local scale = self:GetEffectiveScale()
            local x, y = GetCursorPosition()
            x, y = x / scale, y / scale + CURSOR_DROP
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", nil, "BOTTOMLEFT", x - 40, y > 350 and y or 350)
        end
        SyncPanelLevel(self)
    end)

    frame:HookScript("OnHide", function()
        if not IsActive() then
            return
        end
        if flying > 0 then
            closePending = true
        else
            HidePanel()
        end
    end)
end

-- ============================================================================
-- LIFECYCLE
-- ============================================================================

function LootSkinModule:Apply()
    if self.applied or not addon:IsModuleEnabled("loot_skin") then
        return
    end

    local frame = _G.LootFrame
    if not frame then
        return
    end

    frameOriginal = frameOriginal or {
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        hitRect = { frame:GetHitRectInsets() },
    }

    self.applied = true
    self.initialized = true

    BuildPanel(frame)
    StripVanillaArt(frame)
    SkinCloseButton()

    frame:SetWidth(FRAME_WIDTH)
    -- Left enabled, StartMoving lifts its setAllPoints TitleRegion over the panel and eats row clicks.
    frame:EnableMouse(false)
    rowCount = 0
    EnsureRows(VANILLA_ROWS)

    SyncPanelLevel(frame)

    local CP = addon.CharacterPanel
    if CP and CP.ReskinScrollBar then
        -- Retail hangs its MinimalScrollBar 16px in from the panel's right edge, 28 down and 6 up.
        CP.ReskinScrollBar(clip, panel, 21, -8, -1, true)
        SyncPanelLevel(frame)

        local bar = ScrollBar()
        local grabber = bar and bar._duiGrabber
        -- Its own frame, so it outlives a hidden bar: parked over the rows it would eat their clicks.
        if grabber and not grabber._dragonuiTiedToBar then
            grabber._dragonuiTiedToBar = true
            bar:HookScript("OnShow", function()
                grabber:Show()
            end)
            bar:HookScript("OnHide", function()
                grabber:Hide()
            end)
            if not bar:IsShown() then
                grabber:Hide()
            end
        end
    end

    InstallHooks(frame)

    for index = 1, rowCount do
        StyleRow(index, true)
    end
    ResizeFrame(frame)

    if frame:IsShown() then
        panel:Show()
    end

    events:RegisterEvent("LOOT_OPENED")
    events:RegisterEvent("LOOT_SLOT_CLEARED")
    events:RegisterEvent("LOOT_CLOSED")
end

function LootSkinModule:Restore()
    if not self.applied then
        return
    end
    self.applied = false

    events:UnregisterAllEvents()
    StopScroll()
    isAutoLoot = false
    wipe(slotCache)

    ResetAnimations()
    for _, card in ipairs(cards) do
        card:Hide()
    end
    panel:Hide()

    for _, button in pairs(extraRows) do
        button:Hide()
    end
    rowCount = 0
    wipe(hitTop)
    wipe(hitBottom)

    for index = 1, VANILLA_ROWS do
        local button = _G["LootButton" .. index]
        if button then
            button:EnableMouse(true)
        end
        local ring = button and button._dragonuiSlotBorder
        if ring then
            ring:Hide()
        end
        local text = _G["LootButton" .. index .. "Text"]
        if text then
            text:SetJustifyV("MIDDLE")
        end
        if extraRows[index] then
            extraRows[index]:EnableMouse(true)
        end
    end

    RestoreRemembered()

    local frame = _G.LootFrame
    if frame and frameOriginal then
        frame:EnableMouse(true)
        frame:SetWidth(frameOriginal.width)
        frame:SetHeight(frameOriginal.height)
        frame:SetHitRectInsets(unpack(frameOriginal.hitRect))
    end
end

function LootSkinModule:Refresh()
    if addon:IsModuleEnabled("loot_skin") then
        self:Apply()
    else
        self:Restore()
    end
end
