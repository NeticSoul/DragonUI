local addon = select(2, ...)
local L = addon.L

local _G = _G
local ipairs = ipairs
local pairs = pairs
local unpack = unpack
local wipe = wipe
local tremove = tremove
local max = math.max
local GetTime = GetTime
local NUM_LOOT_BUTTONS = LOOTFRAME_NUMBUTTONS or 4

local assets = addon._dir
local textures = {
    background = assets .. "UI\\ui-background-rock",
    close = assets .. "UI\\redbutton2x",
    slot = assets .. "Bags\\bagsitemslot2x",
    pushed = assets .. "UI\\ui-quickslot-depress",
    highlight = assets .. "UI\\buttonhilight-square",
    slotBorder = assets .. "UI\\ui-quickslot2",
}

local FRAME_WIDTH = 220
-- Below this the 75px top and 32px bottom nineslice corners collide and the side rails invert.
local FRAME_MIN_HEIGHT = 112
local ROW_TOP = 26
local ROW_PITCH = 48
local ROW_HEIGHT = 46
local ROW_INSET = 6
local CARD_WIDTH = FRAME_WIDTH - ROW_INSET * 2
local ICON_X = 12
local ICON_SIZE = 37
local PAGER_BAND = 28

-- Retail LootFrame.xml SlideOutRightAnim: 100px over 0.3s, alpha 1->0 over 0.2s after a 0.1s hold.
local EXIT_DISTANCE = 100
local EXIT_DURATION = 0.3
local EXIT_FADE_DELAY = 0.1
local EXIT_FADE_DURATION = 0.2
-- Retail gets its cascade from the server clearing slots one at a time; 3.3.5a's "loot all" clears
-- every slot in one packet, so the stagger has to be reproduced here or the rows leave as one blur.
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
            -- relativeTo comes back nil for parent-anchored regions, so the arity is stored
            -- alongside the tuple: unpack would stop at that hole.
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

-- Size is snapshotted here rather than in Remember: regions that ship with neither size nor
-- anchors fill their parent, and handing them back an explicit size would pin them instead.
local function Resize(object, width, height)
    local snapshot = originals[Remember(object)]
    if not snapshot.sized then
        snapshot.sized = true
        snapshot.width, snapshot.height = object:GetWidth(), object:GetHeight()
    end
    object:SetWidth(width)
    object:SetHeight(height)
end

-- Only what we hid is shown again: a button's own state textures carry a visibility flag the
-- button drives, and re-Show()ing those would strand a pushed/highlight overlay on screen.
local function HideVanilla(region)
    if region then
        originals[Remember(region)].hidden = region:IsShown()
        region:Hide()
    end
end

local function RestoreRemembered()
    for object, snapshot in pairs(originals) do
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

-- Every pixel of the skin lives on this frame rather than on LootFrame, so the shell can outlive
-- the window: LOOT_CLOSED hides LootFrame outright and the fly-outs would be cut off mid-flight.
local panel, title, clip, canvas
local cards = {}

local function BuildPanel(frame)
    if panel then
        return
    end

    panel = CreateFrame("Frame", nil, UIParent)
    panel:SetFrameStrata("HIGH")
    panel:SetAllPoints(frame)
    panel:Hide()

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

    -- 3.3.5a has no SetClipsChildren; a ScrollFrame is the only thing that clips drawing, and
    -- clipping is what keeps the fly-out inside the window the way retail's ScrollBox does.
    clip = CreateFrame("ScrollFrame", nil, panel)
    clip:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_INSET, -ROW_TOP)
    clip:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -ROW_INSET, ROW_INSET)

    canvas = CreateFrame("Frame", nil, clip)
    canvas:SetSize(CARD_WIDTH, ROW_PITCH * NUM_LOOT_BUTTONS)
    clip:SetScrollChild(canvas)
end

-- The chrome lives on the panel but the loot buttons stay on LootFrame, so the panel has to sit a
-- level under it. Cards share the panel's level rather than taking +1: LootFrame can be level 0,
-- and at +1 they would tie with the buttons and cover the icons.
local function SyncPanelLevel(frame)
    local level = max(0, frame:GetFrameLevel() - 1)
    panel:SetFrameLevel(level)
    clip:SetFrameLevel(level + 2)
    for _, card in ipairs(cards) do
        card:SetFrameLevel(level)
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
    card:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 16 })
    card:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)

    card.fill = card:CreateTexture(nil, "BACKGROUND")
    card.fill:SetTexture("Interface\\Buttons\\WHITE8X8")
    card.fill:SetAllPoints(card)

    card.rarity = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    card.rarity:SetFont(card.rarity:GetFont(), 8)
    card.rarity:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -5)
    card.rarity:SetJustifyH("RIGHT")

    card:Hide()
    return card
end

local function PaintCard(card, quality, showRarity)
    local color = quality and ITEM_QUALITY_COLORS[quality]
    if color then
        card.fill:SetVertexColor(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.45)
    else
        card.fill:SetVertexColor(0, 0, 0, 0.35)
    end

    local rarity = showRarity and quality and _G["ITEM_QUALITY" .. quality .. "_DESC"]
    if rarity then
        card.rarity:SetText(rarity)
        card.rarity:SetVertexColor(color.r, color.g, color.b)
        card.rarity:Show()
    else
        card.rarity:Hide()
    end
end

-- ============================================================================
-- EXIT ANIMATION
-- ============================================================================

local ghostPool = {}
local flying = 0
local closePending = false

local function CreateGhost()
    local ghost = CreateCard(canvas)
    ghost:SetWidth(CARD_WIDTH)
    ghost:SetHeight(ROW_HEIGHT)

    ghost.slot = ghost:CreateTexture(nil, "BACKGROUND")
    ghost.slot:SetTexture(textures.slot)
    ghost.slot:SetSize(ICON_SIZE, ICON_SIZE)
    ghost.slot:SetPoint("TOPLEFT", ghost, "TOPLEFT", ICON_X - ROW_INSET, -4)

    ghost.icon = ghost:CreateTexture(nil, "BORDER")
    ghost.icon:SetAllPoints(ghost.slot)

    ghost.ring = ghost:CreateTexture(nil, "BORDER")
    ghost.ring:SetTexture(textures.slotBorder)
    ghost.ring:SetSize(64, 64)
    ghost.ring:SetPoint("CENTER", ghost.slot, "CENTER", 0, -1)

    ghost.count = ghost:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
    ghost.count:SetPoint("BOTTOMRIGHT", ghost.slot, "BOTTOMRIGHT", -5, 2)
    ghost.count:SetJustifyH("RIGHT")

    ghost.text = ghost:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    ghost.text:SetPoint("LEFT", ghost.slot, "RIGHT", 8, 0)
    ghost.text:SetPoint("RIGHT", ghost, "RIGHT", -6, 0)
    ghost.text:SetJustifyH("LEFT")
    ghost.text:SetWordWrap(false)

    return ghost
end

local function AcquireGhost()
    for _, ghost in ipairs(ghostPool) do
        if not ghost:IsShown() then
            return ghost
        end
    end
    local ghost = CreateGhost()
    ghostPool[#ghostPool + 1] = ghost
    return ghost
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
    for _, ghost in ipairs(ghostPool) do
        ghost:SetAlpha(1)
        ghost:Hide()
    end
    flying = 0
    closePending = false
    panel:SetAlpha(1)
end

local function OnGhostFinished(ghost)
    ghost:Hide()
    ghost:SetAlpha(1)
    flying = flying - 1
    if flying == 0 and closePending then
        Tween(0, CLOSE_FADE_DURATION, function(progress)
            panel:SetAlpha(1 - progress)
        end, HidePanel)
    end
end

local function PlayExit(entry)
    local ghost = AcquireGhost()
    local color = entry.quality and ITEM_QUALITY_COLORS[entry.quality]
    local top = -(entry.index - 1) * ROW_PITCH

    PaintCard(ghost, entry.quality, not entry.isCoin)
    ghost.icon:SetTexture(entry.texture)
    ghost.ring:SetVertexColor(color and color.r or 0.6, color and color.g or 0.6, color and color.b or 0.6)
    ghost.text:SetText(entry.name or "")
    ghost.text:SetVertexColor(color and color.r or 1, color and color.g or 1, color and color.b or 1)
    if entry.count then
        ghost.count:SetText(entry.count)
        ghost.count:Show()
    else
        ghost.count:Hide()
    end

    ghost:ClearAllPoints()
    ghost:SetPoint("TOPLEFT", canvas, "TOPLEFT", 0, top)
    ghost:SetAlpha(1)
    ghost:Show()
    flying = flying + 1

    Tween((entry.index - 1) * EXIT_STAGGER, EXIT_DURATION, function(progress)
        ghost:SetPoint("TOPLEFT", canvas, "TOPLEFT", EXIT_DISTANCE * progress * progress, top)
        local fade = (progress * EXIT_DURATION - EXIT_FADE_DELAY) / EXIT_FADE_DURATION
        ghost:SetAlpha(fade > 0 and 1 - fade * fade or 1)
    end, function()
        OnGhostFinished(ghost)
    end)
end

-- ============================================================================
-- LOOT FRAME
-- ============================================================================

local slotCache = {}
local isAutoLoot = false

local function WheelPage(_, delta)
    if not IsActive() then
        return
    end
    if delta > 0 then
        if _G.LootFrameUpButton:IsShown() then
            LootFrame_PageUp()
        end
    elseif _G.LootFrameDownButton:IsShown() then
        LootFrame_PageDown()
    end
end

local function ApplyLayout(frame)
    frame:SetWidth(FRAME_WIDTH)
    -- Vanilla reserves the right 70px of the 256px frame for art the skin no longer draws.
    frame:SetHitRectInsets(0, 0, 0, 0)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", WheelPage)

    for i = 1, NUM_LOOT_BUTTONS do
        local button = _G["LootButton" .. i]
        if button then
            Remember(button):ClearAllPoints()
            button:SetPoint("TOPLEFT", frame, "TOPLEFT", ICON_X, -(ROW_TOP + 4 + (i - 1) * ROW_PITCH))
            -- Whole card is one hit target, so hovering or clicking anywhere on the row works.
            button:SetHitRectInsets(
                -(ICON_X - ROW_INSET),
                -(FRAME_WIDTH - ROW_INSET - ICON_X - ICON_SIZE),
                -4,
                -5
            )
        end
    end

    local up, down = _G.LootFrameUpButton, _G.LootFrameDownButton
    if up then
        Remember(up):ClearAllPoints()
        up:SetPoint("BOTTOM", frame, "BOTTOM", -14, 6)
    end
    if down then
        Remember(down):ClearAllPoints()
        down:SetPoint("BOTTOM", frame, "BOTTOM", 14, 6)
    end
end

local function SkinCloseButton(frame)
    local button = _G.LootCloseButton
    if not button then
        return
    end

    Resize(button, 24, 24)
    button:ClearAllPoints()
    button:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 1, 0)

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

local function SkinPagerButton(button, atlas)
    if not button then
        return
    end

    -- 20x18 keeps the arrow art's 14x12 aspect, so the state textures can just fill the button.
    Resize(button, 20, 18)

    local states = {
        { button:GetNormalTexture(), atlas .. "-normal" },
        { button:GetPushedTexture(), atlas .. "-pushed" },
        { button:GetHighlightTexture(), atlas .. "-highlight" },
        { button:GetDisabledTexture(), atlas .. "-pushed" },
    }
    for _, state in ipairs(states) do
        if state[1] then
            addon:SafeSetAtlas(Remember(state[1]), state[2], false)
        end
    end
end

local function SkinItemButton(index)
    local button = _G["LootButton" .. index]
    if not button then
        return
    end

    HideVanilla(_G["LootButton" .. index .. "NameFrame"])

    -- Vanilla's normal texture IS the 64x64 quickslot ring; swap it for the flat plate and
    -- rebuild the ring separately so quality tinting never fights Blizzard's locked-item red.
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

    -- Separate BORDER texture: 3.3.5a's SetDrawLayer takes no sublevel, so the ring
    -- has to be created after the icon to sit above it.
    local ring = button._dragonuiSlotBorder
    if not ring then
        ring = button:CreateTexture(nil, "BORDER")
        button._dragonuiSlotBorder = ring
    end
    ring:SetTexture(textures.slotBorder)
    ring:SetSize(64, 64)
    ring:ClearAllPoints()
    ring:SetPoint("CENTER", button, "CENTER", 0, -1)
    ring:Show()

    local text = _G["LootButton" .. index .. "Text"]
    if text then
        Resize(text, FRAME_WIDTH - ROW_INSET - ICON_X - ICON_SIZE - 8, text:GetHeight())
        text:SetWordWrap(false)
    end
end

local function StyleRow(index)
    if not IsActive() then
        return
    end

    local button, card = _G["LootButton" .. index], cards[index]
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

    PaintCard(card, quality, not isCoin)
    card:Show()

    local ring = button._dragonuiSlotBorder
    if ring then
        ring:SetVertexColor(color and color.r or 0.6, color and color.g or 0.6, color and color.b or 0.6)
    end

    if slot then
        local count = _G["LootButton" .. index .. "Count"]
        slotCache[slot] = {
            index = index,
            quality = quality,
            isCoin = isCoin,
            texture = _G["LootButton" .. index .. "IconTexture"]:GetTexture(),
            name = _G["LootButton" .. index .. "Text"]:GetText(),
            count = count:IsShown() and count:GetText() or nil,
        }
    end
end

local function ResizeFrame(frame)
    local rows = 0
    for i = 1, NUM_LOOT_BUTTONS do
        if _G["LootButton" .. i]:IsShown() then
            rows = i
        end
    end
    if rows == 0 then
        rows = 1
    end

    local paged = _G.LootFrameUpButton:IsShown() or _G.LootFrameDownButton:IsShown()
    local height = ROW_TOP + rows * ROW_PITCH - (ROW_PITCH - ROW_HEIGHT) + (paged and PAGER_BAND or ROW_INSET)
    frame:SetHeight(height > FRAME_MIN_HEIGHT and height or FRAME_MIN_HEIGHT)
end

local function OnLootFrameUpdate()
    if not IsActive() then
        return
    end
    -- PREV/NEXT are ARTWORK strings on the frame; the bottom rail would bury them anyway.
    _G.LootFramePrev:Hide()
    _G.LootFrameNext:Hide()
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
    elseif event == "LOOT_CLOSED" then
        isAutoLoot = false
        wipe(slotCache)
    elseif event == "LOOT_SLOT_CLEARED" and _G.LootFrame:IsShown() then
        local entry = slotCache[arg1]
        if not entry then
            return
        end
        slotCache[arg1] = nil

        -- Blizzard's own handler already ran: it hid the row, and may have paged the
        -- next batch into it, in which case StyleRow has re-shown the card.
        if not _G["LootButton" .. entry.index]:IsShown() then
            cards[entry.index]:Hide()
        end
        if isAutoLoot then
            PlayExit(entry)
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

    for i = 1, NUM_LOOT_BUTTONS do
        local button = _G["LootButton" .. i]
        if button then
            button:HookScript("OnEnter", function()
                if IsActive() then
                    cards[i]:SetBackdropBorderColor(1, 1, 1, 1)
                end
            end)
            button:HookScript("OnLeave", function()
                if IsActive() then
                    cards[i]:SetBackdropBorderColor(0.5, 0.5, 0.5, 1)
                end
            end)
        end
    end
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
    SkinCloseButton(frame)
    SkinPagerButton(_G.LootFrameUpButton, "ui-hud-actionbar-pageuparrow")
    SkinPagerButton(_G.LootFrameDownButton, "ui-hud-actionbar-pagedownarrow")
    ApplyLayout(frame)

    for i = 1, NUM_LOOT_BUTTONS do
        SkinItemButton(i)
        if not cards[i] then
            cards[i] = CreateCard(panel)
        end
        cards[i]:ClearAllPoints()
        cards[i]:SetPoint("TOPLEFT", panel, "TOPLEFT", ROW_INSET, -(ROW_TOP + (i - 1) * ROW_PITCH))
        cards[i]:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -ROW_INSET, -(ROW_TOP + (i - 1) * ROW_PITCH))
        cards[i]:SetHeight(ROW_HEIGHT)
        StyleRow(i)
    end

    SyncPanelLevel(frame)
    InstallHooks(frame)

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
    isAutoLoot = false
    wipe(slotCache)

    ResetAnimations()
    for _, card in ipairs(cards) do
        card:Hide()
    end
    panel:Hide()

    local frame = _G.LootFrame
    if frame then
        frame:SetScript("OnMouseWheel", nil)
        frame:EnableMouseWheel(false)
        if frameOriginal then
            frame:SetWidth(frameOriginal.width)
            frame:SetHeight(frameOriginal.height)
            frame:SetHitRectInsets(unpack(frameOriginal.hitRect))
        end
    end

    for i = 1, NUM_LOOT_BUTTONS do
        local button = _G["LootButton" .. i]
        local ring = button and button._dragonuiSlotBorder
        if ring then
            ring:Hide()
        end
        local text = _G["LootButton" .. i .. "Text"]
        if text then
            text:SetWordWrap(true)
        end
    end

    RestoreRemembered()
end

function LootSkinModule:Refresh()
    if addon:IsModuleEnabled("loot_skin") then
        self:Apply()
    else
        self:Restore()
    end
end
