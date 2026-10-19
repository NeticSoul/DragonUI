-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Portrait-off ("compact") layouts: each portrait kind with its art minus the ring, in the same descriptor.
local addon = select(2, ...)
local UF = addon.UF

local ART = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Compact\\"
local FOREVER_ART = ART .. "Forever\\"

local function Copy(source)
    local copy = {}
    for k, v in pairs(source) do
        copy[k] = v
    end
    return copy
end

-- Same canvas, size and anchor as the portrait piece (gen_compact_frames.py), so only the file changes.
local function Swap(piece, file)
    local copy = Copy(piece)
    copy.file = file
    return copy
end

-- Name strips closing like they open (mirrored): 0.5 past the health bar's right as they start 0.5 before its left.
local STRIP = { w = 127, right = 254 / 512 }

for _, style in ipairs({ "dragonui", "forever" }) do
    local skin = UF.SKINS[style]
    local art = style == "forever" and FOREVER_ART or ART

    -- The bars, texts and glows keep the portrait frame's spots; only what sat round the ring moves.
    local player = Copy(skin.player)
    player.background = Swap(skin.player.background, art .. "Player-BACKGROUND")
    player.border = Swap(skin.player.border, art .. "Player-BORDER")
    player.glows = {
        status = Swap(skin.player.glows.status, ART .. "Player-Status"),
        combat = Swap(skin.player.glows.combat, ART .. "Player-InCombat"),
    }
    -- Forever's badge and level circle on the background's TOPLEFT, where the ring was.
    player.pvp = { x = 49.5, y = 4, scale = 0.8 }
    player.level = { x = 47.5, y = -46 }
    skin.playerCompact = player

    -- With a decoration the dragon wraps the frame's left end: badge and circle step below its wing.
    local decorated = Copy(player)
    decorated.pvp = { x = 47.5, y = -13.5, scale = 0.8 }
    decorated.level = { x = 45.5, y = -56 }
    skin.playerCompactDecoration = decorated

    local target = Copy(skin.target)
    target.background = Swap(skin.target.background, art .. "Target-BACKGROUND")
    target.border = Swap(skin.target.border, art .. "Target-BORDER")
    -- The mana's well closes where health's does, 0.5 in like its left end.
    target.bars = { health = skin.target.bars.health, mana = Copy(skin.target.bars.mana) }
    target.bars.mana.w = 125
    target.bars.mana.x = skin.target.bars.health.x - 0.5
    -- Forever's canvas is 4 taller (TARGET_LIFT in uf_skins.lua), so its spots sit 4 lower on it.
    local lift = style == "forever" and 4 or 0
    target.pvp = { x = 174, y = -15.5 - lift, scale = 0.8 }
    target.level = { x = 147.5, y = -45.5 - lift }
    target.flash = Swap(skin.target.flash, ART .. "Target-InCombat")
    local strip = Swap(skin.target.nameBackground, art .. (style == "forever" and "Target-Type" or "Target-NameStrip"))
    strip.w = STRIP.w
    strip.cells = {}
    for key, tc in pairs(skin.target.nameBackground.cells) do
        strip.cells[key] = { tc[1], STRIP.right, tc[3], tc[4] }
    end
    target.nameBackground = strip
    skin.targetCompact = target

    local small = Copy(skin.small)
    small.background = Swap(skin.small.background, art .. "TargetofTarget-BACKGROUND")
    small.border = Swap(skin.small.border, art .. "TargetofTarget-BORDER")
    -- LEFT of each bar on the portrait's RIGHT: both wells widened left across the portrait's spot.
    small.bars = {
        health = { w = 84.5, h = 10, x = -12, y = 1 },
        mana = { w = 84.5, h = 7.5, x = -12, y = -9 },
    }
    small.name = { x = -8, y = 13, w = 76 }
    skin.smallCompact = small
end

-- The player's fills close at both ends; the target and ToT ones run dark under the ring.
UF.TEXTURES.compact = {
    BAR_PREFIX = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\Bars\\UI-HUD-UnitFrame-Player-PortraitOn-Bar-",
}

-- Bent cells from export_compact.py; band, top, combo (beside the combo column) and nose.x from the frame end.
UF.COMPACT_DRAGONS = {
    dragonui = {
        -- Retail's open jaw makes the snout's tip a chin: the nose sits 3 back and 2 up from it.
        elite = { w = 66, h = 71, x = -48.5, y = 27, tc = { 0, 132 / 256, 0, 142 / 256 }, band = -32.5, top = 8.5,
                  combo = 14, nose = { x = -44, y = 17 } },
        rare = { w = 66, h = 71.5, x = -48.5, y = 27, tc = { 0, 132 / 256, 0, 143 / 256 }, band = -32.5, top = 9,
                 combo = 14.5, nose = { x = -44, y = 17 } },
        rareelite = { w = 77, h = 82, x = -48.5, y = 26.5, tc = { 0, 154 / 256, 0, 164 / 256 }, band = -32.5,
                      top = 14, combo = 25, nose = { x = -44, y = 17.5 } },
    },
    forever = {
        gold = { w = 71.5, h = 78, x = -50.5, y = 26.5, tc = { 0, 143 / 256, 0, 156 / 256 }, band = -35.5,
                 top = 8.5, combo = 17.5, nose = { x = -49, y = 20 }, paw = true },
        goldWinged = { w = 83, h = 78, x = -51.5, y = 27, tc = { 0, 166 / 256, 0, 156 / 256 }, band = -36,
                       top = 8.5, combo = 27.5, nose = { x = -49.5, y = 19.5 }, paw = true },
        silverWinged = { w = 85, h = 80.5, x = -54, y = 27, tc = { 0, 170 / 256, 0, 161 / 256 }, band = -36.5,
                         top = 8, combo = 27.5, nose = { x = -50, y = 19.5 }, paw = true },
    },
}
for setKey, cells in pairs(UF.COMPACT_DRAGONS) do
    for cell, place in pairs(cells) do
        place.file = (setKey == "forever" and FOREVER_ART or ART) .. "Dragon-" .. cell
        -- Forever's paw grips the bottom rim: its own cell, drawn over the rims (export_compact.py).
        place.pawFile = place.paw and place.file .. "-Paw" or nil
    end
end

-- Spots that are not skin pieces (units, SetPoint convention).
UF.COMPACT = {
    -- The rim's tips end 1 out of the bars.
    plateEnd = 1,
    player = {
        -- The whole PlayerFrame moves left into the ring's spot, short of the screen edge for the PvP emblem.
        shift = 41.5,
        -- The visible frame (rims, band) on PlayerFrame, x from the left and y down: what the editor box wraps.
        box = { 99, 19.5, 226.5, 66.5 },
        -- Classic PvP emblem: ink ends 3 off the rim or level circle, centred on the rims (33..66 down PlayerFrame).
        pvpIcon = { right = 96, midY = 49.5, circle = 59 },
        -- Zzz TOPLEFT on the health bar's TOPLEFT: its ink over the band's top-left corner, rising up and right.
        rest = { x = 3, y = 39, size = 28 },
        -- Forever's PvP badge spans 68..97 on PlayerFrame; a Zzz pushed off the corner stays left of it too.
        badgeLeft = 68,
        -- With a decoration: smaller, its first "z" out of the dragon's nose (UF.COMPACT_DRAGONS nose).
        noseRest = { size = 20, gap = 1 },
        -- Combat text CENTER on the portrait's.
        hit = { x = -4, y = 0 },
        -- On the level's box, which it hides: 5 in from the bar's end, 3 over it (LFG roles never meet the raid tab).
        role = { x = 208, y = -19, w = 12, h = 12 },
    },
    -- Moves with the player, so the two keep today's distance; the focus has no player beside it.
    targetShift = 41.5,
    targetBox = { 1, 19.5, 129, 66.5 },
    -- ToT/ToF: start where their ring did, their debuffs alongside.
    smallShift = 24,
    smallBox = { 27, 3.5, 113.5, 36.5 },
    -- Where the Zzz flipbook's ink sits in each 64x64 cell: x0, x1, its first "z" bottom-left (x, y down).
    restInk = { 5 / 64, 57 / 64, 8 / 64, 54 / 64 },
    target = {
        -- x from the health bar's right: the target's left sits 128 before it, its background's 128.5.
        frameHealthRight = 128,
        bgHealthRight = 128.5,
        -- Forever's level circle ends 38.5 past the health bar's right.
        circleRight = 38.5,
        -- Classic PvP emblem mirroring the player's: ink gap past whatever ends the frame, centred on the rims.
        pvpIcon = { gap = 3, midY = 49.5 },
        -- Combo column (combopoints.lua): small orbs, the lowest on the bottom rim (32 under the health top).
        combo = { scale = 0.45, pitch = 9.75, size = 10, bottom = -32, gap = 3, dragonGap = 2 },
        raid = { x = 147.5, y = -12 },
        -- Crown TOPRIGHT on the frame's TOPLEFT, over the level.
        leader = { x = 20, y = -4, w = 16, h = 16 },
        foreverLeader = { x = 20, y = -5.75, w = 16, h = 12.5 },
        -- Threat percentage BOTTOM on the frame's TOP; left of a dragon's neck when there is one.
        threat = { x = -51, y = -20 },
        threatDragon = { x = -79, y = -20 },
    },
    -- Under a player decoration's neck its name drops 1.5 (the neck runs along the band's top 4-6 units).
    dragonDrop = 1.5,
    nameGap = 2,
}

-- Portrait off for this frame now: its own option, and never in a vehicle (that art keeps its portrait).
function UF.IsCompact(unitKey)
    local config = UF.GetConfig(unitKey)
    if not config.portrait_off then
        return false
    end
    if unitKey == "player" and UnitHasVehicleUI("player") then
        return false
    end
    return true
end

-- How far left of its box or parent spot a frame hangs now (0 with its portrait, and always for the focus).
function UF.CompactShift(unitKey)
    if not UF.IsCompact(unitKey) then
        return 0
    end
    if unitKey == "player" then
        return UF.COMPACT.player.shift
    elseif unitKey == "target" then
        return UF.COMPACT.targetShift
    elseif unitKey == "tot" or unitKey == "fot" then
        return UF.COMPACT.smallShift
    end
    return 0
end

-- Fits a box's outline to rect (x0, y0, x1, y1 on frame, hung CENTER on the box at ox, oy); nil: whole box.
function UF.FitEditorBox(box, frame, ox, oy, rect, scale)
    if not box or not frame then return end
    if rect then
        local bw, bh = box:GetWidth(), box:GetHeight()
        local dx = bw / 2 + ox - frame:GetWidth() / 2
        local dy = bh / 2 - oy - frame:GetHeight() / 2
        box.DragonUI_BoxInsets = { rect[1] + dx, bw - (rect[3] + dx), rect[2] + dy, bh - (rect[4] + dy) }
    else
        box.DragonUI_BoxInsets = nil
    end
    addon.SetEditorBoxScale(box, scale or 1)
end

-- Zzz TOPLEFT on the health bar's TOPLEFT and its size: on the band's corner, or out of a decoration's nose.
function UF.CompactRestSpot(dragon)
    local ink = UF.COMPACT.restInk
    if dragon and dragon.nose then
        local spot = UF.COMPACT.player.noseRest
        -- Mirrored, the nose is -nose.x right of the frame's left end, which lies plateEnd left of the bar.
        local noseX = -UF.COMPACT.plateEnd - dragon.nose.x
        return noseX + spot.gap - ink[3] * spot.size, dragon.nose.y + spot.gap + ink[4] * spot.size, spot.size
    end
    local rest = UF.COMPACT.player.rest
    return rest.x, rest.y, rest.size
end

-- Returns the bent dragon for a classification (UF.DRAGON_SETS kind) or nil when the set has none for it.
function UF.GetCompactDragon(kind, forcedSet)
    local setKey = UF.DRAGON_SETS[forcedSet] and forcedSet or UF.GetDragonSet()
    local cell = UF.DRAGON_SETS[setKey].kinds[kind] or kind
    return UF.COMPACT_DRAGONS[setKey] and UF.COMPACT_DRAGONS[setKey][cell]
end

-- A compact frame keeps its portrait hidden; Blizzard's health checks reset its alpha through SetVertexColor.
function UF.KeepPortraitHidden(texture, unitKey)
    if not texture or texture.DragonUI_CompactAlpha then
        return
    end
    texture.DragonUI_CompactAlpha = true
    local function Hide(self)
        if UF.IsCompact(unitKey) and self:GetAlpha() > 0 then
            self:SetAlpha(0)
        end
    end
    hooksecurefunc(texture, "SetAlpha", Hide)
    hooksecurefunc(texture, "SetVertexColor", Hide)
end

-- point, x, y, width, justify of a compact player's name on the health bar's TOPLEFT (dragon: its cell).
function UF.CompactPlayerName(dragon)
    local forever = UF.GetLevelStyle() == "forever"
    local point, x, y, w = "BOTTOMLEFT", 12, 2, 90
    local justify = "LEFT"
    if forever then
        point, x, y, w = "LEFT", 4, 7.5, 96
        justify = UF.GetNameSpotJustify()
    end
    if dragon then
        y = y - (forever and 2.5 or UF.COMPACT.dragonDrop)
        -- Mirrored, the head reaches -band past the frame's left end: the name starts a gap after it.
        local start = -UF.COMPACT.plateEnd - dragon.band + UF.COMPACT.nameGap
        if start > x then
            w, x = w - (start - x), start
        end
    end
    return point, x, y, w, justify
end

-- Compact target/focus name on the health bar's TOPLEFT: the player's height, short of a dragon's head.
function UF.CompactTargetName(dragon, healthWidth)
    local forever = UF.GetLevelStyle() == "forever"
    local limit = dragon and (healthWidth + UF.COMPACT.plateEnd + dragon.band - UF.COMPACT.nameGap)
    if forever then
        local w = 100
        if limit and limit - 4 < w then
            w = limit - 4
        end
        return "LEFT", 4, 7.5, w, UF.GetNameSpotJustify()
    end
    -- Centred over the bar, clear of the level (right edge 18 in) and of a dragon's head.
    local left, w = 26, 96
    if limit and left + w > limit then
        left, w = 22, limit - 22
    end
    return "BOTTOM", left + w / 2, 2, w, "CENTER"
end

local function IconAt(spot, x)
    return { x = x, y = spot.y, w = spot.w, h = spot.h }
end

-- Crown and looter spots on PlayerFrame's TOPLEFT: today's, or past a decoration's snout and Zzz.
function UF.GetPlayerIcons()
    if not UF.IsCompact("player") then
        return UF.PLAYER_ICONS
    end
    local config = UF.GetConfig("player")
    local decoration = UF.PLAYER_DECORATIONS[config.dragon_decoration or "none"]
    local dragon = decoration and UF.GetCompactDragon(decoration.kind, decoration.set)
    local spots = UF.PLAYER_ICONS
    local icons = {}
    for k, v in pairs(spots) do icons[k] = v end
    icons.role = UF.COMPACT.player.role
    if dragon then
        local step = spots.master.x - spots.leader.x
        local span = step + spots.master.w
        -- The health bar's LEFT is 100 in: the crown starts 2 past the Zzz rising from the snout.
        local x, _, size = UF.CompactRestSpot(dragon)
        local left = 100 + x + UF.COMPACT.restInk[2] * size + 2
        local tab = _G.DragonUIPlayerGroupIndicator
        if tab and tab:IsShown() and left + span > spots.tab.x - tab:GetWidth() - 1 then
            -- No room before the raid tab: 3 clear of the dragon's back, whose outer edge is -top from the end.
            left = 100 - UF.COMPACT.plateEnd - dragon.top - 3 - span
        end
        icons.leader = IconAt(spots.leader, left)
        icons.foreverLeader = IconAt(spots.foreverLeader, left)
        icons.master = IconAt(spots.master, left + step)
    end
    return icons
end

-- Each 64x64 PvP emblem's solid ink: left, top, right, bottom; Horde's round shield is wider.
local PVP_INK = {
    Alliance = { 11, 3.5, 31.5, 37 },
    Horde = { 4.5, 3.5, 36, 35.5 },
    FFA = { 10.5, 0.5, 31.5, 37 },
}

-- The TOPRIGHT y that centres an emblem's ink midY below its frame's top.
local function PvPInkY(ink, midY)
    return (ink[2] + ink[4]) / 2 - midY
end

-- The classic emblem's TOPRIGHT offsets on the 232-wide PlayerFrame: past a shown level circle and dragon too.
function UF.CompactPlayerPvPIcon(circle, dragon, kind)
    local spot = UF.COMPACT.player.pvpIcon
    local right = spot.right
    if circle then
        right = math.min(right, spot.circle)
    end
    if dragon then
        -- The mirrored dragon's cell starts 100 - x - w in, with a unit of clear edge.
        right = math.min(right, 98 - dragon.x - dragon.w)
    end
    local ink = PVP_INK[kind] or PVP_INK.Horde
    return right - ink[3] + 64 - 232, PvPInkY(ink, spot.midY)
end

-- Where a dragon ends beside the combo column's rows, where the PvP emblem stands too.
local function DragonEnd(dragon)
    return UF.COMPACT.plateEnd + dragon.combo
end

-- Where the target's rim, its dragon and Forever's level circle stop, x from the health bar's right.
local function TargetEnd(circle, dragon)
    local edge = UF.COMPACT.plateEnd
    if circle then
        edge = math.max(edge, UF.COMPACT.target.circleRight)
    end
    if dragon then
        edge = math.max(edge, DragonEnd(dragon))
    end
    return edge
end

-- Centre x of the target's combo column: gap past the frame's end, a little less past a dragon.
function UF.CompactComboX(circle, dragon)
    local combo = UF.COMPACT.target.combo
    local x = TargetEnd(circle) + combo.gap
    if dragon then
        x = math.max(x, DragonEnd(dragon) + combo.dragonGap)
    end
    return x + combo.size / 2
end

-- Where the PvP emblem may start: past the frame's end, or past the combo column while it is up.
local function TargetPvPLeft(circle, dragon, combo)
    local edge = TargetEnd(circle, dragon)
    if combo then
        edge = UF.CompactComboX(circle, dragon) + UF.COMPACT.target.combo.size / 2
    end
    return edge + UF.COMPACT.target.pvpIcon.gap
end

-- The classic emblem's TOPRIGHT offsets on the 232-wide texture frame, which shares the target's left.
function UF.CompactTargetPvPIcon(circle, dragon, kind, combo)
    local left = TargetPvPLeft(circle, dragon, combo)
    local ink = PVP_INK[kind] or PVP_INK.Horde
    return left - ink[1] + UF.COMPACT.target.frameHealthRight + 64 - 232, PvPInkY(ink, UF.COMPACT.target.pvpIcon.midY)
end

-- The raid mark's centre x on the target's TOPLEFT, left of a combo column that is up; half its width given.
function UF.CompactRaidX(circle, dragon, combo, half)
    local raid = UF.COMPACT.target.raid
    if not combo then
        return raid.x
    end
    local target = UF.COMPACT.target
    local columnLeft = UF.CompactComboX(circle, dragon) - target.combo.size / 2
    return math.min(raid.x, target.frameHealthRight + columnLeft - 1 - half)
end

-- A Forever PvP badge's centre x on the background, past a combo column that is up; half its width given.
function UF.CompactTargetBadgeX(x, circle, dragon, combo, half)
    if not combo then
        return x
    end
    return math.max(x, UF.COMPACT.target.bgHealthRight + TargetPvPLeft(circle, dragon, true) + half)
end

-- combopoints.lua hangs the target's column here; target_style.lua moves it with the dragon and level circle.
function UF.GetComboSlot()
    local slot = _G.DragonUI_TargetComboSlot
    if not slot then
        slot = CreateFrame("Frame", "DragonUI_TargetComboSlot", TargetFrame)
        slot:SetSize(1, 1)
    end
    return slot
end

-- Mouse area insets (left, right, top, bottom); the frame is protected, so this waits for combat to end.
function UF.SetHitRect(frame, queueKey, left, right, top, bottom)
    addon:SafeExecute("uf_compact", queueKey, function()
        frame:SetHitRectInsets(left, right, top, bottom)
    end)
end
