-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- Modules read these tables at apply time, never into a file local, so a style switch is a refresh.
local addon = select(2, ...)
local UF = addon.UF

local ART = "Interface\\AddOns\\DragonUI\\Textures\\UnitFrames\\"
local FULL_TEXCOORD = { 0, 1, 0, 1 }

-- Piece x, y are added to the offset the module already anchors with (SetPoint convention, +y up).
UF.SKINS = {
    dragonui = {
        target = {
            -- Registered by the ring; the 2x wells sit 1 lower and 1 further left, hence the bars.
            background = { file = ART .. "HD\\Target-BACKGROUND", w = 256, h = 128, x = -0.5, y = -2.5 },
            border = { file = ART .. "HD\\Target-BORDER", w = 256, h = 128, x = 0, y = 0 },
            -- Centred on the HD ring; the 1x ring's thick inner shadow used to hide a 1.75 px offset.
            portrait = { w = 54, h = 54, x = -48.75, y = -14.75 },
            -- RIGHT of each bar to the portrait's LEFT.
            bars = {
                health = { w = 126, h = 20, x = -1.25, y = -2.25 },
                mana = { w = 133, h = 9.5, x = 6.25, y = -18.75 },
            },
            -- Forever's PvP badge TOP and level circle CENTER on the background's TOPLEFT, mirroring the player's.
            pvp = { x = 194.33, y = -22, scale = 0.8 },
            level = { x = 177.83, y = -55.5 },
            -- With the Forever level the name left-aligns across the freed spot: LEFT on the background, 117 wide.
            name = { x = 4, y = -15.5, w = 117 },
            -- Combat flash BOTTOMLEFT on TargetFrame: its box lines land on the HD contours.
            flash = { x = 1, y = 24 },
            -- Name strip BOTTOMLEFT on HealthBar's TOPLEFT, placed like retail's; DragonUI's PTR cells, solid left.
            nameBackground = {
                file = ART .. "HD\\Target-NameStrip", w = 134, h = 15.5, x = -0.5, y = -0.5,
                blend = "ADD", color = { 1, 1, 1 }, cells = {},
                tapped = { cell = "green", blend = "BLEND", desaturate = true, color = { 0.08, 0.08, 0.08 } },
            },
        },
        -- Player decoration without fat (fat keeps its 1x art): the HD target mirrored, on the health bar's LEFT.
        playerDecoration = {
            background = { file = ART .. "HD\\Target-BACKGROUND", w = 256, h = 128, x = -126.5, y = -30.5, tc = { 1, 0, 0, 1 } },
            border = { file = ART .. "HD\\Target-BORDER", w = 256, h = 128, x = -126.5, y = -30.5, tc = { 1, 0, 0, 1 } },
            -- On PlayerPortrait's RIGHT: health starts under the ring, both stop where the end line's chamfer begins.
            bars = {
                health = { w = 127, h = 20, x = -1, y = -1.5 },
                mana = { w = 131, h = 9, x = 126, y = -17.5 },
            },
            -- How far each bar's ends moved from the text layout; a 3rd value moves only the left text (mana's % under health's).
            edges = { health = { -2, -1 }, mana = { 0, -1, -6 } },
            -- The ring curves past the mana's start: half-unit strips of one texture column, { row down, left } on it.
            manaCorner = {
                step = 0.5, column = 7.5 / 128,
                rows = { { 1.5, -0.5 }, { 2, -0.5 }, { 2.5, -1 }, { 3, -1.5 }, { 3.5, -2 }, { 4, -2 }, { 4.5, -2.5 },
                         { 5, -3 }, { 5.5, -3.5 }, { 6, -4 }, { 6.5, -4.5 }, { 7, -5 }, { 7.5, -5.5 }, { 8, -6 },
                         { 8.5, -6.5 } },
            },
            -- Same glow as Forever: the target's flash at its approved spot on this art, mirrored with it.
            glows = {
                status = { file = ART .. "Forever\\Target-InCombat", w = 188, h = 67, x = 66.5, y = 1.5,
                           tc = { 376 / 512, 0, 0, 134 / 256 } },
                combat = { file = ART .. "Forever\\Target-InCombat", w = 188, h = 67, x = 66.5, y = 1.5,
                           tc = { 376 / 512, 0, 0, 134 / 256 } },
            },
            pvp = { x = 61.67, y = -22, scale = 0.8 },
            level = { x = 78.17, y = -55.5 },
            name = { x = 6, y = 7.5, w = 96 },
        },
        -- Fat decoration: the same art without the health/mana line (gen_uf_fat.py), at the same screen spot.
        playerDecorationFat = {
            background = { file = ART .. "HD\\Target-Fat-BACKGROUND", w = 256, h = 128, x = -126.5, y = -25, tc = { 1, 0, 0, 1 } },
            border = { file = ART .. "HD\\Target-Fat-BORDER", w = 256, h = 128, x = -126.5, y = -25, tc = { 1, 0, 0, 1 } },
            -- One bar from the health well's top to the mana well's bottom; the fat mana bar sits apart.
            bars = {
                health = { w = 127, h = 31, x = -1, y = -7 },
            },
            edges = { health = { -2, -1 } },
            -- The lower well opens left under the ring, as the mana's did: strips measured on this art.
            healthCorner = {
                step = 0.5, column = 7.5 / 128,
                rows = { { 20.5, -3 }, { 21, -3 }, { 21.5, -3 }, { 22, -3.5 }, { 22.5, -3.5 }, { 23, -4 },
                         { 23.5, -4 }, { 24, -4.5 }, { 24.5, -5 }, { 25, -5.5 }, { 25.5, -5.5 }, { 26, -6 },
                         { 26.5, -6.5 }, { 27, -7 }, { 27.5, -7.5 }, { 28, -8 }, { 28.5, -8 }, { 29, -9 },
                         { 29.5, -9.5 }, { 30, -10 }, { 30.5, -10.5 } },
            },
        },
        -- Both anchor to the portrait; the HD ring lands on its centre, the bar end 0.5 under the contour.
        small = {
            background = { file = ART .. "HD\\TargetofTarget-BACKGROUND", w = 128, h = 64, x = -0.5, y = -0.5 },
            border = { file = ART .. "HD\\TargetofTarget-BORDER", w = 128, h = 64, x = -0.5, y = -0.5 },
            -- Pet glows: the party's ToT glow, 1.25 right and 0.25 up of the border like there, ring on the portrait.
            flash = { file = ART .. "HD\\Party-InCombat", w = 114, h = 47, x = 0.75, y = 8.25,
                      tc = { 0, 228 / 256, 0, 94 / 128 } },
        },
        -- Retail's party shares the ToT's contour, so the HD ToT pair serves; all TOPLEFT on the party frame.
        party = {
            background = { file = ART .. "HD\\TargetofTarget-BACKGROUND", w = 128, h = 64, x = 1, y = -2 },
            border = { file = ART .. "HD\\TargetofTarget-BORDER", w = 128, h = 64, x = 1, y = -2 },
            bars = {
                health = { w = 71, h = 10, x = 44, y = -18.5 },
                mana = { w = 74, h = 7, x = 41, y = -29.5 },
            },
            -- Aggro glow: retail's ToT one in 2x, its ring on the portrait (lines and end within 0.25).
            flash = { file = ART .. "HD\\Party-InCombat", w = 114, h = 47, x = 2.25, y = -1.75,
                      tc = { 0, 228 / 256, 0, 94 / 128 } },
        },
        -- Normal player frame (fat keeps its own art); both pieces on the health bar's LEFT.
        player = {
            background = { file = ART .. "HD\\Player-BACKGROUND", w = 256, h = 128, x = -67, y = -28 },
            border = { file = ART .. "HD\\Player-BORDER", w = 256, h = 128, x = -67, y = -28 },
            -- The copper wedge's CENTER on the portrait's, moved with the ring.
            corner = { x = 16.5, y = -16.5 },
            -- Retail's 2x Status and InCombat, TOPLEFT on the background's TOPLEFT at retail's anchors.
            glows = {
                status = { file = ART .. "Forever\\Player-Status", w = 196, h = 71, x = 0, y = 0.5,
                           tc = { 0, 392 / 512, 0, 142 / 256 } },
                combat = { file = ART .. "Forever\\Player-InCombat", w = 192, h = 71, x = 1.5, y = 1,
                           tc = { 0, 384 / 512, 0, 142 / 256 } },
            },
            -- LEFT on PlayerPortrait's RIGHT, the art riding on the health: HD ring centred, health between its lines.
            bars = {
                health = { w = 125, h = 20, x = 2, y = -1 },
                mana = { w = 125, h = 9, x = 2, y = -17 },
            },
            -- This background's TOPLEFT is the Forever player's, so Forever's spots carry over unchanged.
            pvp = { x = -1, y = -25.5, scale = 0.8 },
            level = { x = 15.5, y = -59 },
            -- Forever's PlayerName (TOPLEFT (88, -27), 96 wide): LEFT on HealthBar's TOPLEFT, 4 in from the ring.
            name = { x = 4, y = 7.5, w = 96 },
        },
    },
}

-- Forever shares the HD geometry (identical bar lines, ring within a texel); only the art changes.
do
    local d = UF.SKINS.dragonui
    local function art(piece, file, y)
        local copy = {}
        for k, v in pairs(piece) do
            copy[k] = v
        end
        copy.file = ART .. "Forever\\" .. file
        copy.y = y or piece.y
        return copy
    end
    -- The Forever target canvas carries 8 texels of room above the cell for the ring shadow the c60 sheet clips.
    local TARGET_LIFT = 4
    -- The same screen spot sits TARGET_LIFT further down from this taller canvas's TOPLEFT.
    local function below(spot)
        local copy = {}
        for k, v in pairs(spot) do
            copy[k] = v
        end
        copy.y = spot.y - TARGET_LIFT
        return copy
    end
    local deco = d.playerDecoration
    UF.SKINS.forever = {
        target = {
            background = art(d.target.background, "Target-BACKGROUND", d.target.background.y + TARGET_LIFT),
            border = art(d.target.border, "Target-BORDER"),
            portrait = d.target.portrait,
            -- Forever's wells are translucent, so each bar covers its well exactly (the HD mana left 0.75 open).
            bars = {
                health = d.target.bars.health,
                mana = { w = 133, h = 10, x = 6.25, y = -18.25 },
            },
            pvp = below(d.target.pvp),
            flash = d.target.flash,
            level = below(d.target.level),
            name = below(d.target.name),
            -- Forever's ReputationColor, colours baked (dark mode tints); 0.5 under retail to meet the top line.
            nameBackground = {
                file = ART .. "Forever\\Target-Type", w = 135, h = 18, x = -0.5, y = -3.5,
                blend = "BLEND", color = { 1, 1, 1 }, cells = {},
                tapped = { cell = "grey" },
            },
        },
        playerDecoration = {
            background = art(deco.background, "Target-BACKGROUND", deco.background.y + TARGET_LIFT),
            border = art(deco.border, "Target-BORDER", deco.border.y + TARGET_LIFT),
            bars = {
                health = { w = 127, h = 20, x = -1, y = -1.5 },
                mana = { w = 131, h = 10, x = 126, y = -17.5 },
            },
            edges = deco.edges,
            manaCorner = {
                step = 0.5, column = 7.5 / 128,
                rows = { { 2, -0.5 }, { 2.5, -1 }, { 3, -1 }, { 3.5, -1.5 }, { 4, -2 }, { 4.5, -2 }, { 5, -2.5 },
                         { 5.5, -3 }, { 6, -3.5 }, { 6.5, -4 }, { 7, -4.5 }, { 7.5, -5 }, { 8, -5.5 }, { 8.5, -6 },
                         { 9, -6.5 }, { 9.5, -7 } },
            },
            pvp = below(deco.pvp),
            -- On the health bar, not the canvas.
            name = deco.name,
            level = below(deco.level),
            -- Both glows: the target's InCombat, mirrored like the art, widened 0.4% about the ring to its end line.
            glows = {
                status = { file = ART .. "Forever\\Target-InCombat", w = 188.75, h = 67, x = 65.875, y = -2,
                           tc = { 376 / 512, 0, 0, 134 / 256 } },
                combat = { file = ART .. "Forever\\Target-InCombat", w = 188.75, h = 67, x = 65.875, y = -2,
                           tc = { 376 / 512, 0, 0, 134 / 256 } },
            },
        },
        small = {
            background = art(d.small.background, "TargetofTarget-BACKGROUND"),
            border = art(d.small.border, "TargetofTarget-BORDER"),
            flash = d.small.flash,
        },
        -- Forever's own party cell (1x only, upscaled by the generator), registered by its ring.
        party = {
            background = { file = ART .. "Forever\\Party-BACKGROUND", w = 128, h = 64, x = 1.5, y = -1.25 },
            border = { file = ART .. "Forever\\Party-BORDER", w = 128, h = 64, x = 1.5, y = -1.25 },
            bars = {
                health = { w = 71, h = 10, x = 44.5, y = -18.25 },
                mana = { w = 74, h = 7, x = 41.5, y = -29.25 },
            },
            -- Its lines sit 0.25 lower than retail's: the glow splits that with the ring (0.25 each).
            flash = { file = ART .. "HD\\Party-InCombat", w = 114, h = 47, x = 2.25, y = -1.5,
                      tc = { 0, 228 / 256, 0, 94 / 128 } },
        },
        player = {
            -- The c60 cell is the whole frame, so its fill shares the border's canvas and anchor.
            background = art(d.player.border, "Player-BACKGROUND", -28),
            border = art(d.player.border, "Player-BORDER", -28),
            -- The copper wedge is baked into the art: the corner piece only shows as the combat swords.
            corner = false,
            -- The art rides on the health bar: these carry the c60 ring, 1.5 left and 1 high, onto the portrait.
            bars = {
                health = { w = 125, h = 20, x = 2.5, y = -1.5 },
                mana = { w = 125, h = 10, x = 2.5, y = -17.5 },
            },
            pvp = d.player.pvp,
            level = d.player.level,
            name = d.player.name,
            glows = d.player.glows,
            swords = { file = ART .. "Forever\\Player-CombatIcon", w = 16, h = 16, x = 47, y = -47.5 },
        },
        -- Fat: the art above without the health/mana line, at the same spot, so its level, PvP and glows carry over.
        playerFat = {
            background = { file = ART .. "Forever\\Player-Fat-BACKGROUND", w = 256, h = 128, x = -67, y = -22.5 },
            border = { file = ART .. "Forever\\Player-Fat-BORDER", w = 256, h = 128, x = -67, y = -22.5 },
            -- Covers both wells exactly, as the health and mana bars do between them.
            bars = {
                health = { w = 125, h = 31, x = 2.5, y = -7 },
            },
        },
        playerDecorationFat = {
            background = { file = ART .. "Forever\\Target-Fat-BACKGROUND", w = 256, h = 128, x = -126.5, y = -21, tc = { 1, 0, 0, 1 } },
            border = { file = ART .. "Forever\\Target-Fat-BORDER", w = 256, h = 128, x = -126.5, y = -21, tc = { 1, 0, 0, 1 } },
            bars = d.playerDecorationFat.bars,
            edges = d.playerDecorationFat.edges,
            healthCorner = {
                step = 0.5, column = 7.5 / 128,
                rows = { { 20.5, -3 }, { 21, -3 }, { 21.5, -3 }, { 22, -3.5 }, { 22.5, -3.5 }, { 23, -4 },
                         { 23.5, -4 }, { 24, -4.5 }, { 24.5, -5 }, { 25, -5 }, { 25.5, -5.5 }, { 26, -6 },
                         { 26.5, -6.5 }, { 27, -7 }, { 27.5, -7.5 }, { 28, -7.5 }, { 28.5, -8 }, { 29, -8.5 },
                         { 29.5, -9 }, { 30, -10 }, { 30.5, -10.5 } },
            },
        },
    }
    -- The combat/rest glows trace the frame too: same pieces and spots, minus the health/mana line.
    local f = UF.SKINS.forever
    local function fatGlows(glows, file)
        return { status = art(glows.status, file), combat = art(glows.combat, file) }
    end
    d.playerDecorationFat.glows = fatGlows(d.playerDecoration.glows, "Target-InCombat-Fat")
    f.playerDecorationFat.glows = fatGlows(f.playerDecoration.glows, "Target-InCombat-Fat")
    -- The player's rest glow is only the top halo, with no line to drop.
    f.playerFat.glows = { status = d.player.glows.status, combat = art(d.player.glows.combat, "Player-InCombat-Fat") }
end

-- One cell per colour, in the generator's order: HD/Target-NameStrip 268x31 every 32, Forever/Target-Type 270x36.
for row, key in ipairs({ "blue", "green", "orange", "red", "yellow", "grey" }) do
    if row <= 5 then
        UF.SKINS.dragonui.target.nameBackground.cells[key] = { 0, 268 / 512, (row - 1) * 32 / 256, ((row - 1) * 32 + 31) / 256 }
    end
    UF.SKINS.forever.target.nameBackground.cells[key] = { 0, 270 / 512, (row - 1) * 36 / 256, row * 36 / 256 }
end

-- Forever's level badge, cut from the c60 sheet at its 1x atlas sizes.
UF.LEVEL_ART = {
    file = ART .. "Forever\\Level",
    circle = { w = 39, h = 39, tc = { 0, 78 / 128, 0, 78 / 128 } },
    skull = { w = 18, h = 23, tc = { 80 / 128, 116 / 128, 0, 46 / 128 } },
    -- Forever's WhiteLargeNumberFont: Friz Quadrata 14, centred 0.5 below the circle's middle.
    fontSize = 14,
    textY = -0.5,
}

-- Fat and vehicle art have no Forever spot: badge TOP on PlayerPortrait's LEFT, its (20,-50) at 0.8 x0.93.
UF.PLAYER_PVP_FALLBACK = { x = -7.5, y = 8.4 }

-- One sheet: retail's 2x crown, guide and "Group N" tab, its 1x tiny roles, and Forever's own HD crown and roles.
do
    local function cell(x, y, w, h)
        return { x / 256, (x + w) / 256, y / 128, (y + h) / 128 }
    end
    UF.STATUS_ICONS = {
        file = ART .. "Icons\\StatusIcons",
        leader = { dragonui = cell(0, 0, 32, 32), forever = cell(68, 0, 38, 30) },
        guide = cell(34, 0, 32, 32),
        roles = {
            dragonui = { TANK = cell(0, 50, 16, 16), HEALER = cell(18, 50, 16, 16), DAMAGER = cell(36, 50, 16, 16) },
            forever = { TANK = cell(108, 0, 46, 46), HEALER = cell(156, 0, 46, 46), DAMAGER = cell(204, 0, 46, 46) },
        },
        tabLeft = cell(56, 50, 10, 26),
        tabRight = cell(68, 50, 14, 32),
        -- Stretched sideways: half a texel in keeps the neighbours out of the filter.
        tabMid = { 84.5 / 256, 115.5 / 256, 50 / 128, 76 / 128 },
    }
end

-- Retail's spots +(16, -6.5), clear of Zzz, names, tab, PvP and every dragon; the same with a decoration.
UF.PLAYER_ICONS = {
    leader = { x = 108.5, y = -3.5, w = 16, h = 16 },
    -- Forever's 19x15 crown in the same slot: 16 wide keeps it off the Zzz.
    foreverLeader = { x = 108.5, y = -5.25, w = 16, h = 12.5 },
    master = { x = 126.5, y = -3.5, w = 16, h = 16 },
    -- Retail's (196, -27) 3 to the left, off the tab's right cap; the DragonUI level text hides while it shows.
    role = { x = 209, y = -20.5, w = 12, h = 12 },
    -- BOTTOMRIGHT on PlayerFrame's TOPLEFT, growing left: text width + 40.
    tab = { x = 226, y = -22.5 },
}
-- Target/focus: the crown's TOPRIGHT on the frame's TOPLEFT (retail TOPRIGHT (-85, -8) + (-20.5, -6)).
UF.TARGET_ICONS = {
    leader = { x = 126.5, y = -2, w = 16, h = 16 },
    foreverLeader = { x = 126.5, y = -3.75, w = 16, h = 12.5 },
}

-- Party, TOPLEFT on the member frame: retail's spots, the crown 1 higher to clear our name at (46, -5).
UF.PARTY_ICONS = {
    leader = { x = 42, y = 11, w = 16, h = 16 },
    foreverLeader = { x = 42, y = 9.25, w = 16, h = 12.5 },
    master = { x = 60, y = 11, w = 16, h = 16 },
    role = { x = 103, y = -5, w = 12, h = 12 },
}

-- The status icons follow the unit frame art.
function UF.GetStatusIconStyle()
    return UF.GetFrameStyle() == "forever" and "forever" or "dragonui"
end

-- kinds maps a classification (elite, rare, rareelite, boss) to the cell each set draws for it.
UF.DRAGON_SETS = {
    dragonui = {
        file = ART .. "uiunitframeboss2x",
        cells = {
            elite = { 0.001953125, 0.314453125, 0.322265625, 0.630859375 },
            rare = { 0.00390625, 0.31640625, 0.64453125, 0.953125 },
            rareelite = { 0.001953125, 0.388671875, 0.001953125, 0.31835937 },
        },
        kinds = { elite = "elite", rare = "rare", rareelite = "rareelite", boss = "rareelite" },
    },
    forever = {
        file = ART .. "Forever\\uiunitframeboss2x",
        cells = {
            gold = { 1 / 512, 201 / 512, 1 / 512, 201 / 512 },
            goldWinged = { 1 / 512, 221 / 512, 203 / 512, 383 / 512 },
            silverWinged = { 223 / 512, 441 / 512, 203 / 512, 380 / 512 },
        },
        kinds = { elite = "gold", rare = "silverWinged", rareelite = "silverWinged", boss = "goldWinged" },
    },
}

-- Player Dragon Decoration values: each names its own set, so dragon_style only drives the other frames.
UF.PLAYER_DECORATIONS = {
    elite = { kind = "elite", set = "dragonui" },
    rareelite = { kind = "rareelite", set = "dragonui" },
    elite_forever = { kind = "elite", set = "forever" },
    rareelite_forever = { kind = "rareelite", set = "forever" },
    worldboss_forever = { kind = "boss", set = "forever" },
}

-- [frame][set][cell]: target sits on the portrait CENTER, player on PlayerFrame TOPLEFT. ToT/ToF get none, like retail.
UF.DRAGON_PLACEMENT = {
    target = {
        dragonui = {
            elite = { w = 80, h = 79, x = 4.75, y = -0.25 },
            rare = { w = 80, h = 79, x = 4.75, y = -0.25 },
            rareelite = { w = 99, h = 81, x = 13.75, y = -0.25 },
        },
        forever = {
            gold = { w = 100, h = 100, x = 5.25, y = -1.5 },
            goldWinged = { w = 110, h = 90, x = 11.25, y = -1.5 },
            silverWinged = { w = 110, h = 89, x = 8.25, y = -4 },
        },
    },
    player = {
        -- rest: the Zzz's TOPLEFT on PlayerPortrait's, its first z 2.2-2.4 off the snout so the dragon breathes it.
        dragonui = {
            elite = { w = 80, h = 79, x = 25.5, y = -4, flip = true, rest = { x = 60, y = 20 } },
            rareelite = { w = 99, h = 81, x = 6.5, y = -3, flip = true, rest = { x = 60, y = 20 } },
        },
        forever = {
            gold = { w = 100, h = 100, x = 14.75, y = 5.5, flip = true, rest = { x = 66.5, y = 19.75 } },
            goldWinged = { w = 110, h = 90, x = 3.75, y = 0.5, flip = true, rest = { x = 66.75, y = 20 } },
            silverWinged = { w = 110, h = 89, x = 6.75, y = -2.5, flip = true, rest = { x = 67, y = 19.75 } },
        },
    },
}

-- boss.lua reads this raw shape (cell, w, h, x, y) and stays on the DragonUI set.
do
    local cells = UF.DRAGON_SETS.dragonui.cells
    local function boss(cell, w, h, x, y)
        local c = cells[cell]
        return { c[1], c[2], c[3], c[4], w, h, x, y }
    end
    UF.BOSS_COORDS = {
        targetStyle = {
            elite = boss("elite", 80, 79, 4, 1),
            rare = boss("rare", 80, 79, 4, 1),
            rareelite = boss("rareelite", 99, 81, 13, 1),
        },
    }
end

local function UnitFrameConfig()
    return addon.db and addon.db.profile and addon.db.profile.unitframe
end

function UF.GetFrameStyle()
    local config = UnitFrameConfig()
    local key = config and config.frame_style
    return UF.SKINS[key] and key or "dragonui"
end

function UF.GetFrameSkin()
    return UF.SKINS[UF.GetFrameStyle()]
end

-- "auto" (or anything unknown) follows the frame art, so each art keeps its own look by default.
function UF.GetPvPIconStyle(frameConfig)
    local key = frameConfig and frameConfig.pvp_icon_style
    if key == "classic" or key == "forever" then
        return key
    end
    return UF.GetFrameStyle() == "forever" and "forever" or "classic"
end

function UF.GetLevelStyle()
    local config = UnitFrameConfig()
    local key = config and config.level_style
    if key == "dragonui" or key == "forever" then
        return key
    end
    return UF.GetFrameStyle()
end

-- Forever's level circle spot on the current art, or nil for DragonUI's level text; frameKind is a SKINS key.
function UF.GetLevelSpot(frameKind)
    return UF.GetLevelStyle() == "forever" and UF.GetFrameSkin()[frameKind].level or nil
end

-- The name moves with the level: Forever's left-aligned slot, or nil for each frame's DragonUI placement.
function UF.GetNameSpot(frameKind)
    return UF.GetLevelStyle() == "forever" and UF.GetFrameSkin()[frameKind].name or nil
end

function UF.GetNameSpotJustify()
    local config = UnitFrameConfig()
    return config and config.center_names and "CENTER" or "LEFT"
end

-- "auto" (or anything unknown) follows the frame art, like the level and PvP styles.
function UF.GetDragonSet()
    local config = UnitFrameConfig()
    local key = config and config.dragon_style
    if UF.DRAGON_SETS[key] then
        return key
    end
    return UF.DRAGON_SETS[UF.GetFrameStyle()] and UF.GetFrameStyle() or "dragonui"
end

-- Returns file, left, right, top, bottom and the placement table, or nil when the frame has no such dragon.
function UF.GetDragon(frameKind, kind, forcedSet)
    local setKey = UF.DRAGON_SETS[forcedSet] and forcedSet or UF.GetDragonSet()
    local set = UF.DRAGON_SETS[setKey]
    local cell = set.kinds[kind] or kind
    local placements = UF.DRAGON_PLACEMENT[frameKind]
    local place = placements and placements[setKey] and placements[setKey][cell]
    local c = set.cells[cell]
    if not place or not c then
        return nil
    end
    if place.flip then
        return set.file, c[2], c[1], c[3], c[4], place
    end
    return set.file, c[1], c[2], c[3], c[4], place
end

-- Small text draws low at low pixel density; a line fitted to three in-game measurements, centred from 2.2 px/unit.
function UF.GetLevelTextY(frame)
    local y = UF.LEVEL_ART.textY
    local height = tonumber(string.match(GetCVar("gxResolution") or "", "%d+x(%d+)"))
    if not height or not frame then
        return y
    end
    local ppu = frame:GetEffectiveScale() * height / 768
    return y + math.max(0, math.min(1.7, 1.12 - 1.09 * (ppu - 1.17)))
end

-- Places the circle behind the level text; false (and hidden) when the art has no level badge.
function UF.ApplyLevelCircle(texture, level, background)
    if not level then
        texture:Hide()
        return false
    end
    local circle = UF.LEVEL_ART.circle
    texture:SetTexture(UF.LEVEL_ART.file)
    texture:SetTexCoord(unpack(circle.tc))
    texture:SetSize(circle.w, circle.h)
    texture:ClearAllPoints()
    texture:SetPoint("CENTER", background, "TOPLEFT", level.x, level.y)
    texture:Show()
    return true
end

function UF.ApplySkinPiece(texture, piece, point, relativeTo, relativePoint, x, y)
    texture:SetTexture(piece.file)
    texture:SetTexCoord(unpack(piece.tc or FULL_TEXCOORD))
    texture:SetSize(piece.w, piece.h)
    texture:ClearAllPoints()
    texture:SetPoint(point, relativeTo, relativePoint, x + piece.x, y + piece.y)
end

local SKINNED_FRAME_REFRESHES = {
    "RefreshTargetFrame", "RefreshFocusFrame", "RefreshToTFrame", "RefreshToFFrame", "RefreshPetFrame",
    "RefreshPartyFrames",
}

function UF.RefreshSkins()
    if InCombatLockdown() then
        addon.CombatQueue:Add("uf_refresh_skins", UF.RefreshSkins)
        return
    end
    for _, name in ipairs(SKINNED_FRAME_REFRESHES) do
        local refresh = addon[name]
        if refresh then
            refresh(addon)
        end
    end
    if addon.PlayerFrame and addon.PlayerFrame.RefreshPlayerFrame then
        addon.PlayerFrame.RefreshPlayerFrame()
    end
    -- The level style moves the ToT/ToF, and with them how many aura rows stay short.
    if addon.RefreshTargetFocusAuraLayout then
        addon.RefreshTargetFocusAuraLayout()
    end
    if addon.RefreshDarkModeUnitFrames then
        addon.RefreshDarkModeUnitFrames()
    end
end
