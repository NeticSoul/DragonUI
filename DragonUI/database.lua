-- Copyright (c) 2026 NeticSoul. Licensed under the MIT License; see LICENSE.

-- ============================================================================
-- DragonUI - Database Defaults
-- Defines default profile values for AceDB-3.0. All configurable settings
-- live here as the single source of truth for new/reset profiles.
-- ============================================================================

local addon = select(2, ...);

-- Locale-aware font (set by core/fonts.lua, loaded before this file)
local _arialn = addon.Fonts and addon.Fonts.ARIALN or "Fonts\\ARIALN.TTF"

local defaults = {
    global = {
        locale = "auto", -- UI language override; "auto" follows the client locale
        numberUnits = "auto", -- Large-number units: "auto" keeps 만/억 or 万/亿 on those clients, "western" forces k/M
        defaultProfile = "", -- Profile new characters start on; "" gives each its own
        bagsterCache = {}, -- Per-character bank snapshot (realm|name keys); used by bagster module
        characterMoney = {}, -- Gold per character (realm|name keys); used by the altmoney tooltip
        questLootLearned = {}, -- Learned quest loot sources for nameplates: [mobName] = {objectiveText=true}
        talentBuilds = {}, -- Saved talent builds per class: [CLASS] = { {name, ranks[tab][index], reqLevel}, ... }
        auraDurations = {}, -- Observed debuff durations for nameplates: [spellId] = seconds
        addonIcons = {}, -- Addon manager icons learned from loaded addons: [lowercase folder] = { icon, coords }
        itemOwnership = { version = 1, realms = {} }, -- Per-realm, per-character item counts for the tooltip module
        uiScaleEnabled = false, -- DragonUI sets UIParent's scale itself, which can go below Blizzard's 0.64
        uiScale = false -- That scale; false until first enabled, then seeded from the scale on screen
    },
    profile = {
        -- Keep at 1: version-less legacy profiles read this default and must still run migrations.
        version = 1,
        optionsPanelScale = 1, -- Settings window scale on top of the UI scale
        -- Widgets
        widgets = {
            minimap = {
                anchor = "TOPRIGHT",
                posX = 0,
                posY = 0
            },
            player = {
                anchor = "TOPLEFT",
                posX = 10,
                posY = -9
            },
            target = {
                anchor = "TOPLEFT",
                posX = 230,
                posY = -9
            },
            focus = {
                anchor = "TOPLEFT",
                posX = 250,
                posY = -220
            },
            party = {
                anchor = "TOPLEFT",
                posX = 10,
                posY = -200
            },
            buffs = {
                anchor = "TOPRIGHT",
                posX = -270,
                posY = -15,
                custom_position = false
            },
            weapon_enchants = {
                anchor = "TOPRIGHT",
                posX = -100,
                posY = -15,
                custom_position = false
            },
            debuffs = {
                anchor = "TOPRIGHT",
                posX = -270,
                posY = -75,
                custom_position = false
            },
            pet = {
                anchor = "TOPLEFT",
                posX = 63,
                posY = -105
            },
            petbar = {
                anchor = "BOTTOM",
                posX = 1,
                posY = 146
            },
            playerCastbar = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 200
            },
            gcd = {
                custom_position = false -- sits on the player cast bar until dragged off
            },
            targetCastbar = {
                anchor = "CENTER",
                posX = 0,
                posY = 0
            },
            focusCastbar = {
                anchor = "CENTER",
                posX = 0,
                posY = 0
            },

            mainbar = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 22
            },
            rightbar = {
                anchor = "RIGHT",
                posX = -5,
                posY = -70
            },
            leftbar = {
                anchor = "RIGHT",
                posX = -45,
                posY = -70
            },
            bottombarleft = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 67
            },
            bottombarright = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 106
            },
            micromenu = {
                anchor = "BOTTOMRIGHT",
                posX = -3,
                posY = 3
            },
            bagsbar = {
                anchor = "BOTTOMRIGHT",
                posX = -5,
                posY = 40
            },
            xpbar = {
                anchor = "BOTTOM",
                posX = 1,
                posY = 7
            },
            repbar = {
                anchor = "BOTTOM",
                posX = 1,
                posY = 23
            },
            fat_manabar = {
                anchor = "TOPLEFT",
                posX = 187,
                posY = -9
            },
            tot = {
                anchor = "CENTER",
                posX = 0,
                posY = 0
            },
            fot = {
                anchor = "CENTER",
                posX = 0,
                posY = -100
            },
            vehicleExit = {
                anchor = "BOTTOM",
                posX = -251,
                posY = 145
            },
            lfgframe = {
                anchor = "BOTTOMRIGHT",
                posX = -270,
                posY = 50,
                tooltip_position = "TOP"
            },
            durability = {
                custom_position = false
            },
            tooltip = {
                anchor = "BOTTOMRIGHT",
                posX = -90,
                posY = 100
            },
            errorMessages = {
                anchor = "CENTER",
                posX = 0,
                posY = 160,
                custom_position = false,
                always_hidden = false,
                show_in_combat = false,
                hide_in_combat = false,
            },
            positionPresetPanel = {
                anchor = "TOP",
                posX = 0,
                posY = 144,
                relativePoint = "CENTER",
                custom_position = false
            },
            levelupenhance = {
                anchor = "TOP",
                posX = 0,
                posY = -180
            },
            personalresource = {
                anchor = "CENTER",
                posX = 0,
                posY = -110
            },
            swingtimer_mainhand = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 285
            },
            swingtimer_offhand = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 260
            },
            swingtimer_ranged = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 235
            }
        },
        -- Personal Resource Display: settings (the enable flag is modules.personalresource.enabled)
        personalresource = {
            size = 100,           -- Frame scale in percent (editor slider 70-150)
            bar_width = 100,      -- Width in percent of the 200-unit base (50-150)
            health_height = 15,   -- Health bar height (10-30)
            power_height = 15,    -- Power and alternate power bar height (10-30)
            padding = 0,          -- Extra gap between bars on top of the 4-unit minimum (0-10)
            opacity = 100,        -- Percent (50-100)
            visibility = "always", -- always | combat | hidden
            hide_health = false,
            hide_power = false,
            hide_alt_power = false, -- Druid mana while shapeshifted
            class_color = false,  -- Health bar in the class colour
            bar_text = false,     -- Percentage and value on the bars
        },
        -- Level-up banner (the enable flag is modules.levelupenhance.enabled; position in widgets.levelupenhance)
        levelupenhance = {
            scale = 1,            -- Banner and list scale (0.6-1.6)
            show_unlocks = true,  -- Show what the level unlocks (abilities, features, dungeons, raids, battlegrounds)
            auto_expand = true,   -- Open the list on its own, as retail shows the unlocks without a click
            unlock_style = "banner", -- banner: one at a time inside the banner, as retail | list: a list under it
            chat_unlocks = true,  -- Print the unlocks in the windows that get the level-up message
            pet_levelup = true,   -- Banner when a hunter pet levels up
        },
        -- Combo points (the enable flag is modules.combopoints.enabled)
        combopoints = {
            location = "auto",    -- auto | both | player | target; auto follows unitframe.frame_style
            style = "auto",       -- auto | dragonui | forever: art of the orbs (retail or c60); auto follows unitframe.frame_style
            hide_empty = false,   -- Hide the orbs at 0 points instead of showing empty ones
            detached = false,     -- Player bar moved in the editor: follows widgets.combopoints instead of the player frame
        },
        -- Swing timers, one table per bar (the enable flag is modules.swingtimer.enabled)
        swingtimer = {
            mainhand = {
                scale = 100,          -- Percent (50-200)
                opacity = 100,        -- Percent (50-100)
                width = 307,          -- Units (153-613); Forever's 426 at our HUD's 0.72
                height = 22,          -- Units (11-43); Forever's 30 at our HUD's 0.72
                show_title = true,
                show_time = true,
                visibility = "combat", -- always | combat | hidden
            },
            offhand = {
                scale = 100,
                opacity = 100,
                width = 307,
                height = 22,
                show_title = true,
                show_time = true,
                visibility = "combat",
            },
            ranged = {
                scale = 100,
                opacity = 100,
                width = 307,
                height = 22,
                show_title = true,
                show_time = true,
                visibility = "combat",
            },
        },
        -- Quest Tracker
        questtracker = {
            anchor = "TOPRIGHT",
            x = -210,
            y = -255,
            show_header = true,
            collapsed = false,   -- Survives reloads; Blizzard's own tracker forgets it
            font_size = 12,      -- Point size for quest tracker text (WoW default: 11)
            custom_height = false, -- Off: the tracker runs down to the bags bar or the screen bottom
            height = 400,        -- Cap used when custom_height is on (slider range 400-1000)
            show_on_hover = false,
            show_in_combat = false,
            hide_in_combat = false,
            visibility_logic = "and",
        },
        -- Loot Roll
        lootroll = {
            anchor = "BOTTOM",
            x = 0,
            y = 220,
            autoRoll = false, -- Auto greed/disenchant green BoE rolls at max level
        },
        -- Party Invites
        autoaccept = {
            friends = false, -- Accept party invites from players on the friends list
            guild = false, -- Accept party invites from guild members
        },
        camera = {
            max_distance = false, -- Override cameraDistanceMaxFactor past the 2.0 the Interface slider allows
            factor = 3.4, -- Factor applied while max_distance is on
        },
        -- ACTIONBAR SETTINGS
        mainbars = {
            -- Per-bar layout (nested sub-tables with rows/columns/buttons_shown)
            player = {
                rows = 1,
                columns = 12,
                buttons_shown = 12,
                button_spacing = 7,
                change_button_order = false,
                button_order = "top_left"
            },
            left = {
                horizontal = false,
                rows = 12,
                columns = 1,
                buttons_shown = 12,
                button_spacing = 7,
                change_button_order = false,
                button_order = "top_left"
            },
            right = {
                horizontal = false,
                rows = 12,
                columns = 1,
                buttons_shown = 12,
                button_spacing = 7,
                change_button_order = false,
                button_order = "top_left"
            },
            bottom_left = {
                rows = 1,
                columns = 12,
                buttons_shown = 12,
                button_spacing = 7,
                change_button_order = false,
                button_order = "top_left"
            },
            bottom_right = {
                rows = 1,
                columns = 12,
                buttons_shown = 12,
                button_spacing = 7,
                change_button_order = false,
                button_order = "top_left"
            },

            -- Legacy global spacing; kept as migration source for per-bar button_spacing
            button_spacing = 7,
            spacing_migrated = false,

            -- Per-bar scales
            scale_actionbar = 0.9,
            scale_rightbar = 0.9,
            scale_leftbar = 0.9,
            scale_bottomleft = 0.9,
            scale_bottomright = 0.9,
            scale_vehicle = 1,

            page_by_form = false, -- Main bar pages by the stance bar's form names, for classless servers
        },

        -- ACTION BAR VISIBILITY SETTINGS
        actionbars = {
            -- Enable/disable secondary bars
            bottom_left_enabled = true,
            bottom_right_enabled = true,
            right_enabled = true,
            left_enabled = true,

            -- Hover fade behavior (Bartender4-style)
            visibility_shown_alpha = 1,
            visibility_hidden_alpha = 0,
            visibility_fade_in_duration = 0.15,
            visibility_fade_out_duration = 0.2,
            visibility_fade_out_delay = 0.2,

            -- Micro menu visibility fade behavior
            micro_visibility_shown_alpha = 1,
            micro_visibility_hidden_alpha = 0,
            micro_visibility_fade_in_duration = 0.15,
            micro_visibility_fade_out_duration = 0.2,
            micro_visibility_fade_out_delay = 0.2,

            -- Bag bar visibility fade behavior
            bag_visibility_shown_alpha = 1,
            bag_visibility_hidden_alpha = 0,
            bag_visibility_fade_in_duration = 0.15,
            bag_visibility_fade_out_duration = 0.2,
            bag_visibility_fade_out_delay = 0.2,

            -- Hover/combat visibility per bar
            main_show_on_hover = false,
            main_show_in_combat = false,
            main_hide_in_combat = false,
            main_visibility_logic = "and",
            bottom_left_show_on_hover = false,
            bottom_left_show_in_combat = false,
            bottom_left_hide_in_combat = false,
            bottom_left_visibility_logic = "and",
            bottom_right_show_on_hover = false,
            bottom_right_show_in_combat = false,
            bottom_right_hide_in_combat = false,
            bottom_right_visibility_logic = "and",
            right_show_on_hover = false,
            right_show_in_combat = false,
            right_hide_in_combat = false,
            right_visibility_logic = "and",
            left_show_on_hover = false,
            left_show_in_combat = false,
            left_hide_in_combat = false,
            left_visibility_logic = "and",


            -- Micro menu and bag bar visibility
            micro_always_hidden = false,
            micro_show_on_hover = false,
            micro_show_in_combat = false,
            micro_hide_in_combat = false,
            micro_visibility_logic = "and",
            bag_always_hidden = false,
            bag_show_on_hover = false,
            bag_show_in_combat = false,
            bag_hide_in_combat = false,
            bag_visibility_logic = "and"
        },

        micromenu = {
            -- Legacy/shared settings
            hide_on_vehicle = false,
            bags_collapsed = false,
            grayscale_icons = false,
            show_latency_indicator = true,

            -- Grayscale icons configuration
            grayscale = {
                scale_menu = 1.5,
                x_position = 5,
                y_position = -54,
                icon_spacing = 15, -- Migrated from old stride to padding on first load
                columns = 12, -- 1 = vertical; high = single row
                invert_order = false,
            },

            -- Normal colored icons configuration  
            normal = {
                scale_menu = 0.9,
                x_position = -113,
                y_position = -53,
                icon_spacing = 26, -- Migrated from old stride to padding on first load
                columns = 12, -- 1 = vertical; high = single row
                invert_order = false,
            }
        },

        bags = {
            scale = 1,
            x_position = 1,
            y_position = 41,
            tint_unusable = true, -- Red icon tint for gear/Use items the player cannot use
            new_items = true, -- Glow on items the character just gained (inventory bags; Bagster or bags_skin)
            new_glow_style = "border", -- "border" (soft pulsing ring) or "starburst" (rotating star)
            new_glow_color_mode = "quality", -- "quality" (item rarity colour) or "user" (new_glow_color)
            new_glow_color = { 1, 1, 1, 1 }, -- Glow colour when new_glow_color_mode is "user"
            new_clear_on_close = true, -- Closing a bag clears its glows (Bagster: closing the inventory clears all)
            new_ignore_junk = false, -- Never mark poor-quality items as new
        },

        xprepbar = {
            -- Style: "dragonflightui" (custom bars) or "retailui" (atlas reskin)
            style = "dragonflightui",
            -- Bar dimensions
            bar_width = 466,
            bar_height_dfui = 14,
            bar_height_retailui = 9,
            -- Configurable scales for the bars
            expbar_scale = 1.0,
            repbar_scale = 1.0,
            -- Rested XP
            show_rested_bar = true,
            show_rested_mark = true,
            -- Text display
            always_show_text = false,
            show_xp_percent = false,
            -- Hover/combat visibility (shared by both bars, see core/visibility_fade.lua)
            show_on_hover = false,
            show_in_combat = false,
            hide_in_combat = false,
            visibility_logic = "and",
        },

        style = {
            gryphons = 'new',
            gryphonScale = 1,
            gryphonOffsetX = 0,
            gryphonOffsetY = 0,
            xpbar = 'dragonflightui',
            exhaustion_tick = true -- Show exhaustion tick (on by default)
        },

        buttons = {
            only_actionbackground = true,
            hide_main_bar_background = false,
            hide_slot_backgrounds = false, -- Every button shows only its frame, whatever only_actionbackground says
            tooltips = "always", -- "always", "combat" (hidden in combat) or "never"
            count = {
                show = true
            },
            hotkey = {
                show = true,
                range = true,
                shadow = {0, 0, 0, 1},
                color = {0.6, 0.6, 0.6, 1},
                font = {_arialn, 12, "OUTLINE"},
                font_size = 12,
            },
            macros = {
                show = true,
                color = {.67, .80, .93, 1},
                font = {_arialn, 10, "OUTLINE"}
            },
            pages = {
                show = true,
                font = {_arialn, 12, "OUTLINE"}
            },
            cooldown = {
                color = {1, 1, 1, 1},
                min_duration = 3,
                whole_seconds = false,
                font = {_arialn, 16, "OUTLINE"},
                font_size = 16,
                position = {'CENTER', 0, 1}
            },
            border_color = {1, 1, 1, 1}
        },

        additional = {
            size = 31,
            spacing = 6,
            stance = {
                x_position = -211,
                y_offset = -55, -- Additional Y offset for fine-tuning position
                button_size = 31, -- Size of stance buttons (native Blizzard size)
                button_spacing = 6, -- Spacing between stance buttons
                show_hotkey = false,
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            pet = {
                scale = 1.0,
                grid = false, -- Disable grid by default (matches original Dragonflight port)
                show_hotkey = false,
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            vehicle = {
                x_position = -40,
                y_offset = -5,
                artstyle = true
            },
            totem = {
                x_position = 0,
                y_offset = 2, -- Additional Y offset for fine-tuning position
                button_size = 34, -- Size of totem buttons (native Blizzard size)
                button_spacing = 4, -- Spacing between totem buttons
                manual_position = false, -- When true, uses x_position/y_offset; when false, auto-anchors to action bars
                show_hotkey = false,
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            extrabar1 = {
                x_position = 0,
                y_position = 0, -- screen centre
                scale = 0.9, -- container SetScale, like mainbars scale_actionbar
                size = 36,
                spacing = 7, -- match mainbars.button_spacing / per-bar default
                columns = 12, -- 12 = single row
                buttons_shown = 12,
                change_button_order = false,
                button_order = "bottom_left",
                show_hotkey = true, -- default on: no well-known native binds like pet/stance
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            }
        },

        -- MINIMAP SETTINGS
        minimap = {
            scale = 1,
            style = "dragonui", -- "dragonui", "dragonui_square", "forever" or "forever_square"
            forever_square_border = "frame", -- "frame" (the Forever ring made square) or "thin" (a thin box border)
            forever_square_rounded = false, -- Forever frame on the square: rounded corners instead of right angles
            square_top_arrow = true, -- Forever square: north pointer on the top edge
            border_alpha = 1,
            blip_skin = true, -- true = new/modern style, false = old/classic Blizzard style
            ping_sender = true, -- Name of whoever pinged the minimap, in their class color
            tracking_icons = true,
            zoom_buttons = false,
            calendar = true,
            clock = true,
            clock_font_size = 12,
            player_arrow_size = 40,
            zonetext_font_size = 12,
            settings_button_angle = 203,
            farm_mode_enabled = false, -- Bigger map, chrome hidden; toggled by /dui farm or the panel
            farm_mode_scale = 1.5, -- Extra scale on top of minimap.scale at UI scale 0.8 (clamped to 1-2)
            collector_enabled = true,
            collector_style = "dragonui",
            addon_button_distance = 0, -- Map units LibDBIcon addon buttons move out (+) or in (-) from their usual orbit
            animated_border_enabled = false,
            animated_border_scale = 0.9,
            animated_border_preset = "drg_preset_01",
            animated_border_square_preset = "drg_square_01",
            animated_border_animations = true,
            animated_border_opacity = 1,
            animated_border_hide_dragonui_border = false,
            addon_button_skin = true,
            addon_button_fade = false,
            show_on_hover = false,
            show_in_combat = false,
            hide_in_combat = false,
            visibility_logic = "and",
        },

        --  BUFFS SETTINGS 
        buffs = {
            enabled = true,
            show_toggle_button = true,
            buffs_hidden = false,
            separate_weapon_enchants = false,
            show_debuffs = true,
            buff_horizontal_gap = 0,
            debuff_horizontal_gap = 0,
            buff_scale = 1,
            debuff_scale = 1,
            buffs_per_row = 12,
            debuffs_per_row = 12,
            max_buff_rows = 0,
            max_debuff_rows = 0,
            buff_vertical_gap = 15,
            debuff_vertical_gap = 15,
            debuff_offset_y = 60,
            buff_order = "blizzard",
            layout_preview = false,
            layout_preview_buffs = 40,
            layout_preview_debuffs = 16,
        },

        -- CASTBAR SETTINGS
        castbar = {
            enabled = true,
            hideBlizzard = false, -- with the DragonUI bar off, hide Blizzard's too
            scale = 1,
            text_mode = "simple",
            precision_time = 1,
            precision_max = 1,
            sizeX = 256,
            sizeY = 16,
            showIcon = false,
            sizeIcon = 27,
            modernIconBorder = true,
            holdTime = 0.3,
            holdTimeInterrupt = 0.8,
            interruptShake = true, -- retail-style shake when the player's cast is interrupted
            showInterrupter = true, -- "Interrupted by <name>" on interrupted casts

            -- LATENCY INDICATOR (PLAYER ONLY)
            latency = {
                enabled = false,
                color = { r = 0.9, g = 0.5, b = 0.2 },
                alpha = 0.45,
            },

            -- GLOBAL COOLDOWN INDICATOR (PLAYER ONLY)
            gcd = {
                enabled = false,
                height = 4,           -- bar thickness in pixels
                width = 1,            -- width as a fraction of the cast bar (0.1 - 1)
                alwaysShow = false,   -- keep the empty track visible while the GCD is idle
                style = "castbar",    -- fill: "castbar", "classic", "flat" or "smooth"
                background = "castbar", -- track: "castbar", "dark", "framed" or "none"
                spark = false,        -- spark on the moving edge of the fill
                color = { r = 1, g = 0.7, b = 0 },
            },

            -- TARGET CASTBAR SETTINGS
            target = {
                enabled = true,
                hideBlizzard = false,
                override = false,
                scale = 1,
                x_position = 0,
                y_position = 0,
                text_mode = "simple", -- "simple" (centered spell name only) or "detailed" (name + time)
                precision_time = 1,
                precision_max = 1,
                sizeX = 150,
                sizeY = 10,
                showIcon = true,
                sizeIcon = 20,
                modernIconBorder = true,
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                showInterrupter = true,
                anchorFrame = 'TargetFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM'
            },

            -- FOCUS CASTBAR SETTINGS
            focus = {
                enabled = true,
                hideBlizzard = false,
                override = false,
                scale = 1,
                x_position = 0,
                y_position = 0,
                text_mode = "simple", -- "simple" (centered spell name only) or "detailed" (name + time)
                precision_time = 1,
                precision_max = 1,
                sizeX = 150,
                sizeY = 10,
                showIcon = true,
                sizeIcon = 20,
                modernIconBorder = true,
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                showInterrupter = true,
                anchorFrame = 'FocusFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM'
            }
        },

        -- UNIT FRAMES SETTINGS
        unitframe = {
            scale = 1.0, -- Global scale for all unit frames
            frame_style = "dragonui", -- "dragonui" or "forever": art of every unit frame at once (uf_skins.lua)
            dragon_style = "auto", -- "auto" (follows frame_style), "dragonui" or "forever": elite dragons, with either art
            level_style = "auto", -- "auto" (follows frame_style), "dragonui" or "forever"; the name moves with it
            center_names = false, -- Centre player/target/focus names in the Forever name spot instead of left
            player = {
                enabled = true,
                breakUpLargeNumbers = true,
                scale = 1.0,
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                racePortrait = false, -- Show race icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                portrait_off = false, -- Portrait-off frame: the portrait art without its ring (uf_compact.lua)
                textFormat = "both",
                showHealthTextAlways = false,
                showManaTextAlways = false,
                dragon_decoration = "none",
                show_pvp_icon = true,
                pvp_icon_style = "auto", -- "auto" (follows frame_style), "classic" or "forever" (Forever's round badge)
                alwaysShowAlternateManaText = false,
                alternateManaFormat = "both",
                show_runes = true, -- DK rune display (used by player.lua)
                runes_detached = false, -- DK runes moved in the editor: follow widgets.dkrunes instead of the player frame
                show_rest_glow = true, -- Show golden glow when resting (inn/city)
                combat_flash_enabled = true, -- Enable combat flash pulse animation
                combat_flash_opacity = 1.0, -- Opacity multiplier for combat flash (0.0 - 1.0)
                fat_healthbar = false, -- Full-width health bar 
                fat_manabar_width = 200,
                fat_manabar_height = 8,
                fat_manabar_hidden = false,
                manabar_texture = "dragonui", -- "dragonui", "blizzard", "blizzard_flat", "smooth", "aluminium", "litestep"
                -- Dragonflight-style power bar colors (applied on override textures in fat mode)
                power_colors = {
                    MANA         = { r = 0.02, g = 0.32, b = 0.71 },
                    RAGE         = { r = 1.00, g = 0.00, b = 0.00 },
                    FOCUS        = { r = 1.00, g = 0.50, b = 0.25 },
                    ENERGY       = { r = 1.00, g = 1.00, b = 0.00 },
                    HAPPINESS    = { r = 0.00, g = 1.00, b = 1.00 },
                    RUNES        = { r = 0.50, g = 0.50, b = 0.50 },
                    RUNIC_POWER  = { r = 0.00, g = 0.82, b = 1.00 },
                },
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            target = {
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                racePortrait = false, -- Show race icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                portrait_off = false, -- Portrait-off frame: the portrait art without its ring (uf_compact.lua)
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                enableThreatGlow = true,
                show_name_background = true,
                show_pvp_icon = true,
                pvp_icon_style = "auto",
                show_buffs = true,
                show_debuffs = true,
                scale = 1.0,
                -- Also fades Target of Target and the target cast bar (see target_style.lua)
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            focus = {
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                racePortrait = false, -- Show race icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                portrait_off = false, -- Portrait-off frame: the portrait art without its ring (uf_compact.lua)
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                show_buff_debuff = true,
                show_name_background = true,
                show_pvp_icon = true,
                pvp_icon_style = "auto",
                scale = 0.9,
                -- Also fades Target of Focus and the focus cast bar (see target_style.lua)
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            pet = {
                breakUpLargeNumbers = true,
                textFormat = 'numeric',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                enableThreatGlow = true,
                scale = 1.0,
                override = false,
                x = 18,
                y = -80,
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            party = {
                enabled = true,
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                racePortrait = false, -- Show race icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                orientation = 'vertical',
                padding_vertical = 30,
                padding_horizontal = 50,
                pvp_icon_style = "classic", -- not "auto": party keeps the classic icon on the Forever art too
                scale = 1.0,
                override = false,
                anchor = 'TOPLEFT',
                anchorParent = 'TOPLEFT',
                x = 10,
                y = -200,
                buff_tooltip = "always", -- "always" | "combat" (hidden in combat) | "never": Blizzard's buff box on hover
                always_hidden = false,
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            tot = {
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                racePortrait = false, -- Show race icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                portrait_off = false, -- Portrait-off frame: the portrait art without its ring (uf_compact.lua)
                scale = 1.0,
                x = -35,
                y = -30,
                override = false,
                anchor = 'BOTTOMRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                anchorFrame = 'TargetFrame'
            },
            fot = {
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                racePortrait = false, -- Show race icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                portrait_off = false, -- Portrait-off frame: the portrait art without its ring (uf_compact.lua)
                scale = 1.0,
                x = -35,
                y = -30,
                override = false,
                anchor = 'BOTTOMRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                anchorFrame = 'FocusFrame'
            },
            boss = {
                enabled = true,
                scale = 1.0,
                breakUpLargeNumbers = true,
                textFormat = "both",
                showHealthTextAlways = false,
                showManaTextAlways = false,
                override = false,
                anchor = 'TOPRIGHT',
                anchorParent = 'TOPRIGHT',
                x = -85,
                y = -350,
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            }
        },

        -- Talent window
        talents = {
            scale = 1, -- Talent window scale on top of the UI scale, like the other panels
            glyph_names = false, -- Show each inscribed glyph's name beside its socket
            glyph_effects = true -- Show the active-effects card next to the glyph sockets
        },

        -- MODULES SETTINGS
        modules = {
            noop = {
                enabled = true -- Hide default Blizzard UI elements to allow DragonUI replacements
            },
            cooldowns = {
                enabled = true -- Show cooldown timers on action buttons
            },
            auracooldowns = {
                enabled = false, -- Optional module: customizes target/focus aura icons and timers
                icons_enabled = false,
                timers_enabled = false,
                timer_units = "both",
                duration_anchor = "CENTER",
                duration_offset_x = 0,
                duration_offset_y = 0,
                stack_anchor = "TOPRIGHT",
                stack_offset_x = 0,
                stack_offset_y = 0,
                duration_font = "system",
                count_font = "system",
                buffs = {
                    icon_size = 0,
                    icon_scale = 1,
                    stack_font_size = 0,
                },
                debuffs = {
                    icon_size = 0,
                    icon_scale = 1,
                    stack_font_size = 0,
                },
                target = {
                    enabled = false,
                    min_duration = 0,
                    max_duration_minutes = 0,
                    font_size = 11,
                },
                focus = {
                    enabled = false,
                    min_duration = 0,
                    max_duration_minutes = 0,
                    font_size = 11,
                }
            },
            rage_indicator = {
                enabled = true, -- Tint action button icons by range and usability
                oor_color = { r = 0.8, g = 0.2, b = 0.2 }, -- out of range
                oom_color = { r = 0.5, g = 0.5, b = 1.0 } -- not enough mana
            },
            buttons = {
                enabled = true -- Apply DragonUI button styling and enhancements
            },
            vehicle = {
                enabled = true -- Apply DragonUI vehicle interface enhancements
            },
            stance = {
                enabled = true -- Apply DragonUI stance/shapeshift bar positioning and styling
            },
            talents = {
                enabled = true -- Replace Blizzard's talent and glyph window with the retail-style one
            },
            petbar = {
                enabled = true -- Apply DragonUI pet bar positioning and styling
            },
            multicast = {
                enabled = true -- Apply DragonUI multicast (totem/possess) bar positioning and styling
            },
            extrabar1 = {
                enabled = false -- opt-in standalone bar (#330); Options → Action Bars → Visibility
            },
            micromenu = {
                enabled = true -- Apply DragonUI micro menu and bags system styling and positioning
            },
            mainbars = {
                enabled = true -- Apply DragonUI main action bars, status bars (XP/Rep), scaling, and positioning system
            },
            merchant = {
                enabled = true, -- Retail-style vendor window chrome, sell-all-junk button, and buyback undo arrow
                autoRepair = false, -- Repair all items automatically when a merchant window opens
                autoRepairGuild = false, -- Pay for automatic repairs with guild bank funds when they cover the cost
                autoSellJunk = false -- Sell all grey (junk) items automatically when a merchant window opens
            },
            questdialog = {
                enabled = true -- Retail-style quest and gossip window chrome
            },
            minimap = {
                enabled = true, -- Apply DragonUI minimap enhancements including custom styling, positioning, tracking icons, and calendar
                sexymap_mode = false, -- Must stay falsy: unset means "not chosen yet", so detecting SexyMap asks again
            },
            MinimapDecorations = {
                enabled = true -- Native animated minimap border decorations module
            },
            buffs = {
                enabled = true -- Enable DragonUI buff frame with custom styling, positioning, and toggle button functionality
            },
            auraborders = {
                enabled = true, -- Modern DF-style borders on buff/debuff icons (player/target/focus)
                buff_color = { r = 0.2, g = 0.2, b = 0.2 }, -- neutral buff chrome over white mask; debuffs use dispel-type color
                border_style = "detailed", -- "detailed" (action-bar art), "rounded" (tinted white frame) or "square" (solid lines)
                -- When true, login ApplyDarkMode must not overwrite buff_color (user set it in Auras).
                buff_color_user_override = false,
            },
            keybinding = {
                enabled = true -- Enable LibKeyBound integration for intuitive keybinding (hover + key press)
            },
            questtracker = {
                enabled = true -- Enable DragonUI quest tracker positioning and styling
            },
            keypress = {
                enabled = false -- Fire action-bar abilities on key down instead of key release (inspired by SnowfallKeyPress)
            },
            levelupenhance = {
                enabled = true, -- Enhanced level-up notification with animated frame
            },
            personalresource = {
                enabled = false, -- Small health and power bar under the character (settings in editor mode)
            },
            combopoints = {
                enabled = true, -- Retail orb bar under the player and/or small orbs on the target (Options > Unit Frames)
            },
            totemframe = {
                enabled = true, -- Round totem timers under the player: HD ring, editor spot (shamans)
            },
            swingtimer = {
                enabled = false, -- Main hand, off hand and ranged swing bars (settings in editor mode)
            },
            darkmode = {
                enabled = false, -- Apply darker tinted textures to UI chrome
                intensity_preset = 3, -- 1 = Light, 2 = Medium, 3 = Dark
                use_custom_color = false, -- Override presets with custom color
                custom_color = { r = 0.15, g = 0.15, b = 0.15 } -- Custom tint RGB
            },
            nameplates = {
                enabled = true,
                barWidth = 148, -- Modern's baked art is cut for 148x16; Heritage seeds 150x9 when picked
                barHeight = 16, -- height of the nameplate in pixels
                fontSize = 2, -- Scale 1-10, maps to name/HP font px
                nameFont = "primary", -- font for name/level text (primary, actionbar, narrow, arial, system)
                healthTextFormat = "percent", -- "none" | "percent" | "value" | "valuePercent" (value then percent)
                healthTextPosition = "afterName", -- "afterName" (the name truncates first) | "barRight" | "barCenter" | "barSplit"; a name inside the bar forces "afterName"
                healthNumberFontSize = 2, -- Scale 1-10, font px of health text drawn inside the bar
                nameOverlayHealthBar = false, -- anchor name/level/percent/elite icon centered on the health bar instead of above it
                nameOverlayOffsetY = 0, -- vertical (Y) offset applied when nameOverlayHealthBar is enabled
                nameRowPaddingX = 0, -- horizontal inset (left & right) applied to name/level/percent row; does not affect the elite icon
                eliteIconOffsetY = 0, -- additional vertical offset for the elite/rare icon, independent of the name row / overlay offset
                healthBarBackground = "black", -- black | castbar. "black" uses the dedicated bar-bg-health texture (hand-editable copy); "castbar" reuses bar-bg.
                showPowerBar = false,
                showPowerBarText = true, -- show numeric values on power bar
                powerPlayersOnly = false, -- Hide mana on NPCs
                powerBarBackground = "black", -- black | castbar. "black" uses the dedicated bar-bg-power texture (hand-editable copy); "castbar" reuses bar-bg.
                showCastBar = true,
                castBarOffTargetMode = "safe", -- off | safe | aggressive | hybrid. UI: enable=safe, +aggressive=aggressive, +players-only=hybrid
                castBarHidePetCasts = true, -- all modes: hide cast bars on player pets/guardians (Water Elemental, mirror images, etc.)
                castBarOffTarget = false, -- legacy mirror of aggressive mode
                castBarOffTargetHostileOnly = false, -- legacy reaction filter (no longer exposed in UI; 3.3.5a shows enemy OR ally plates only)
                castBarOffTargetSafeOnly = true, -- legacy mirror of safe mode (now the default)
                castBarPvPAggressive = false, -- legacy reaction filter (no longer exposed in UI)
                showPartyRaidCastBars = true, -- show cast bars on party/raid member nameplates
                castBarModernIconBorder = true, -- action-bar style frame around the cast icon
                castBarModernIconLeft = false, -- Modern style: spell icon left of the cast bar instead of under it
                castBarHeight = 8, -- height of the cast bar in pixels
                castBarGap = 3, -- vertical gap between health, power, and cast bars
                showCastBarSpellName = true, -- show the spell name text on the cast bar (the modern skin is drawn around it)
                castBarSpellNameFontSize = 8, -- font size for the cast bar spell name text
                castBarSpellNameOffsetX = 0, -- horizontal offset for the cast bar spell name text
                castBarSpellNameOffsetY = 0, -- vertical offset for the cast bar spell name text
                threatGlow = false, -- show threat glow indicator (colored border); part of the Heritage art
                tankMode = false, -- invert threat colors for a tank perspective (holding aggro = green)
                dpsMode = false, -- ThreatPlates-style DPS threat colors (in combat); exclusive with tankMode
                raidMarkHealthColor = false, -- tint health bar by raid marker, allies and enemies alike
                tapDeniedGray = true, -- gray health bar when unit is tapped by another player/group (GUID memory)
                showTargetHighlight = true,
                showTargetArrows = false,
                showDebuffs = true,
                maxDebuffs = 5,
                debuffIconSize = 24, -- debuff icon size in pixels
                showDebuffCooldown = true, -- show remaining debuff time text on icons
                debuffCooldownSwipe = true, -- also show a radial cooldown swipe on debuff icons
                debuffCooldownSwipeStyle = "squareSwirl", -- "vertical" | "pie" | "squareSwirl"
                debuffCooldownFontSize = 13, -- font size for debuff remaining time text (retail: 0.55 of the icon)
                debuffCooldownTextAnchor = "center", -- "center" | "topleft" | "topright" | "bottomleft" | "bottomright"
                debuffOnlyTargetFocus = false, -- only show debuffs on target/focus plates
                debuffOnlyMine = false, -- only show debuffs the player applied
                debuffIncludeOtherCC = true, -- let anyone's crowd control through the "only mine" filter
                debuffFilterMode = "all", -- "all" | "whitelist" | "blacklist"
                debuffFilterList = "", -- comma-separated spell IDs for whitelist/blacklist
                debuffFilterRules = {}, -- whitelist only: [spellId] = "any" | "mine"; unset follows debuffOnlyMine
                debuffModernIconBorder = true, -- action-bar style frame around debuff icons
                debuffHighlightCC = true, -- colored border by aura category (crowd control, defensive, dispel type)
                showBuffs = false, -- show enemy buffs in the same row as debuffs, ordered by rank
                buffFilterMode = "purgeable", -- "purgeable" | "all" | "whitelist" | "blacklist"
                buffFilterList = "", -- comma-separated spell IDs for whitelist/blacklist
                -- Editable so the panel can show exactly which buffs count as defensive.
                defensiveBuffList = "642,1022,5599,10278,498,5573,45438,48707,48792,31224,5277,19263,23920,871,12975,22812,61336,33206,47585,46924,8178,51690,1719,12292,47788,6940,64205,70940,3411,55694,30823,55233,49222,19574,34471,53480,45182,66,5384",
                ccExtraList = "", -- extra spell IDs treated as crowd control on top of the built-in list
                showFriendlyAuras = false, -- show auras on friendly plates (never "all", always a criterion)
                friendlyIncludeCC = true, -- also show crowd control on allies, listed or not
                friendlyIncludeDefensive = true, -- also show the defensive cooldowns from defensiveBuffList
                friendlyIncludeAllDebuffs = false, -- show every debuff on allies, not just the curated ones
                -- Battleground flags and support cooldowns: what you want to spot on an ally at a glance.
                friendlyAuraFilterList = "23333,23335,34976,29166,10060,2825,32182,53563,1044,6940,47788,64843,31821",
                auraSortMode = "priority", -- "priority" (own CC first) | "chronological" (expiration only)
                auraHighlightMode = "cc", -- which auras draw larger: "cc" | "list" | "ccAndList" | "none"
                auraHighlightList = "", -- extra spell IDs drawn at the highlight size
                auraHighlightScale = 1.35, -- size multiplier for highlighted auras
                auraColorCCEnabled = false, -- give crowd control its own color instead of its dispel type
                -- Blizzard's DebuffTypeColor values, editable. "none" is what a debuff with no dispel type uses.
                auraColors = {
                    none = { r = 0.80, g = 0, b = 0 },
                    Magic = { r = 0.20, g = 0.60, b = 1.00 },
                    Curse = { r = 0.60, g = 0.00, b = 1.00 },
                    Disease = { r = 0.60, g = 0.40, b = 0 },
                    Poison = { r = 0.00, g = 0.60, b = 0 },
                    Enrage = { r = 1.00, g = 0.55, b = 0.15 },
                    Buff = { r = 0.35, g = 0.70, b = 1.00 },
                    CrowdControl = { r = 1.00, g = 0.25, b = 0.25 },
                },
                debuffOffsetX = 0, -- horizontal offset for the debuff icon row
                debuffOffsetY = 0, -- vertical offset for the debuff icon row
                showDebuffPositionDebug = false, -- persistent debug box showing debuff row bounds
                showRaidMarkers = true, -- show raid target markers (skull, cross, etc.)
                raidMarkerDebuffLayout = false, -- force beside-bar raid marker on all plates (as when showDebuffs)
                showEliteIcon = true, -- show elite/rare dragon icon on nameplates
                eliteIconStyle = "dragon", -- "dragon" | "star" (star uses *-icon-old textures)
                showComboPoints = false, -- show combo points on target nameplate
                questIcons = { -- quest objective icons on nameplates (kill/loot); stock: target/mouseover/focus only, awesome_wotlk: all plates
                    enabled = true,
                    nameResolution = true, -- token-less: match plate name to active objectives (kill: addon-free, loot: quest-addon DB)
                    lootProvider = "auto", -- loot DB source: auto|off|pfquest|questie|questhelper
                    questieCoexist = "ask", -- who draws icons when Questie's own nameplate icons are on: ask|dragonui|questie
                    pointerMode = false, -- always show quest_pointer; skips kill/loot type crossref
                    killIcon = "sword", -- "sword" | "skull"
                    lootIcon = "bag", -- "bag" | "chest"
                    eliteKillIcon = true, -- distinct icon on elite/rare kill objectives
                    testIcon = "off", -- force-preview one icon on all plates for tuning: off|sword|skull|elite|bag|chest|pointer
                    -- Per-icon x/y (from health-bar center) and display size; code-tunable defaults.
                    icons = {
                        sword   = { x = -93, y = 6, size = 24 },
                        skull   = { x = -90, y = 7, size = 22 },
                        elite   = { x = -90, y = 6, size = 26 },
                        bag     = { x = -90, y = 7, size = 26 },
                        chest   = { x = -90, y = 7, size = 22 },
                        pointer = { x = -78, y = 7, size = 28 },
                    },
                },
                showTotemIcons = false, -- show totem icon on shaman totem nameplates
                totemIconPosition = "top", -- "top" | "left" | "right"
                totemIconOnly = false, -- hide the totem nameplate entirely; show only the totem icon
                showTotemTimer = true, -- show remaining life on own totems (requires GetTotemInfo data)
                totemNormalModeList = "", -- comma-separated exact totem names forced to render as a plain plate (no icon)
                centerNameOnly = false, -- center the name in the space the health text leaves
                showLevelInName = false, -- show the level in the nameplate
                showLevelOnHover = false, -- level on hover+target; false = target only
                showLevelAlways = true, -- always show level bracket on any resolvable plate
                levelTextFormat = "plain", -- "brackets" | "parentheses" | "plain"
                nameReactionColors = false, -- tint name text with health-bar reaction color
                enemyNameClassColors = false, -- class colors for enemy player name text
                friendlyNameClassColors = false, -- class colors for friendly player name text (needs bar class options)
                friendlyPlayerColor = { r = 0, g = 0, b = 1 }, -- default friendly player color (vanilla blue)
                friendlyNPCColor = { r = 0, g = 1, b = 0 }, -- default friendly NPC color (green)
                partyClassColors = true, -- use class colors for party members instead of friendlyPlayerColor
                friendlyClassColors = false, -- class-color ALL friendly players (not just group); hover/target on stock, instant with awesome_wotlk
                friendlyNameOnly = false, -- MASTER: enable headline mode (hide health/power/cast bars, show only the name)
                friendlyNameOnlyParty = true, -- headline mode for party/raid members (default on = preserves previous behavior)
                friendlyNameOnlyAll = false, -- headline mode for ALL friendly players (superset of party/raid)
                friendlyNameOnlyColor = { r = 1, g = 1, b = 1 }, -- headline name text color when class colors are not applied (default white)
                friendlyNameOnlyClassColor = false, -- class-color friendly player names while in headline mode (non-group needs awesome_wotlk)
                friendlyNameOnlyGuild = false, -- show <Guild> subtitle for friendly players in headline mode (resolves via target/mouseover, instant with awesome_wotlk)
                friendlyNameOnlyTitle = false, -- show the player's title inline via UnitPVPName (e.g. "Arthas Jenkins")
                friendlyNameOnlyAFK = false, -- show <AFK> for away friendly players in headline mode
                friendlyNPCNameOnly = false, -- headline mode for friendly NPCs
                friendlyNPCNameOnlyTitle = false, -- show <Title/Occupation> subtitle for friendly NPCs (token or unit cache)
                unitCacheRemember = true, -- keep learned players and NPC titles between sessions (per realm / per locale)
                headlineExcludeTarget = false, -- keep health/power/cast bars on the current target while headline mode is active
                enemyPlayerClassColors = false, -- use class colors for enemy player nameplates (ShowClassColorInNameplate)
                disableNonTargetFade = false, -- when true, target/non-target use the same full opacity
                opacityNonTarget = 0.5, -- default non-target opacity
                opacityFullNoTarget = true, -- when no target exists, use full target opacity
                opacityFullParty = false, -- always show party/raid member nameplates at full opacity
                onlyTargetPlates = false, -- hide hostile plates except the target and, in combat, NPCs attacking you
                offsetX = 0, -- horizontal offset from the center of the screen
                offsetY = 0, -- vertical offset from the center of the screen
                clickboxWidthFactor = 1, -- width factor for the clickbox
                clickboxHeightFactor = 1, -- height factor for the clickbox
                showClickbox = false, -- show the clickbox overlay
                totemClickPadding = 8, -- extra clickable padding (px) on totem nameplates
                clampTarget = true, -- keep the target nameplate from leaving the screen top
                clampBoss = true, -- keep boss nameplates clamped in party/raid instances
                clampTopInset = 40, -- distance below the screen top where a clamped plate stops
                depthSortingEnabled = true, -- depth/Z-order sorting for overlapping plates
                plateStyle = "modern", -- "modern" (retail chrome) | "legacy" (the DragonUI art, labelled Heritage)
                retailSelectionBorder = true, -- white glowing border around the target's health bar
                retailDeselectedOverlay = true, -- dim overlay on every plate that is not the target
                retailMouseoverHighlight = true, -- additive wash over the bar while the plate is hovered
                retailThreatColors = true, -- retail yellow/orange threat colors instead of the red/orange/yellow set
                retailTextOutlineInside = true, -- outline the name and health text while the name sits inside the bar
                retailTextOutlineAbove = false, -- outline the name and health text while the name sits above the bar
                retailTargetScale = 1, -- Retail behavior: target scale multiplier
                retailFriendlyScale = 1, -- Retail behavior: friendly plate scale multiplier
                retailStackingEnabled = false, -- Retail-like stacking behavior
                retailStackingInInstance = false, -- If true, stacking only applies in instances
                retailStackingXSpace = 150, -- horizontal spacing between nameplates
                retailStackingYSpace = 24, -- vertical spacing between nameplates
                retailStackingOriginY = 0, -- vertical origin for stacking
                retailStackingFreezeMouseover = false, -- freeze the mouseover position while stacking
                bghCompatEnabled = true, -- compatibility bridge for BattleGroundHealers icon anchoring
                bghIconAnchor = "top", -- "left" | "top" | "right" | "bottom"
                bghIconOffsetX = 0, -- x offset for BattleGroundHealers icon anchor
                bghIconOffsetY = 0, -- y offset for BattleGroundHealers icon anchor
                bghIconSize = 24, -- icon size override used by compatibility bridge
                bghTestMode = false, -- enables manual mark-target testing for BattleGroundHealers compatibility
                nameplateAlphaCompat = false, -- skip forcing native plate alpha to 1, for addons that read it as target identity (PlateBuffs, ...)
                nameplateBarAlphaCompat = false, -- texture-only health-bar hide instead of bar-level SetAlpha, for addons parented to it (Icicle, ...)
            },
            tooltip = {
                enabled = true, -- Enhanced tooltip styling with class colors
                class_colored_border = true, -- Color tooltip border by class/reaction
                class_colored_name = true, -- Color unit name by class
                target_of_target = true, -- Show target-of-target line
                health_bar = true, -- Show health bar on tooltip
                anchor_cursor = false, -- Anchor tooltip to cursor
                anchor_cursor_x = 20, -- X offset from the cursor
                anchor_cursor_y = 20, -- Y offset from the cursor
                show_aura_source = true, -- Show caster name on buff/debuff tooltips
                show_aura_spell_id = false, -- Show spell ID on buff/debuff tooltips
            },
            itemquality = {
                enabled = true, -- Color item borders by quality in bags, character panel, bank, merchant
                min_quality = 2 -- Minimum quality to show (2 = Uncommon/green)
            },
            characterpanel = {
                enabled = true, -- Retail-style reskin of the Blizzard character window
                portrait_style = "spec", -- Portrait art: "character" face, "class" icon or "spec" icon
                class_level_text = true, -- Class-colored "Level X Race Class" line
                dark_background = false, -- Tint the panel's stone grounds down; the cog toggles it
                grey_model_backdrop = true, -- Desaturate and dim the race backdrop behind the model
                hide_model_controls = false, -- Drop the rotate/zoom/reset strip over the 3D model
                model_controls_reset_only = false, -- ...except the reset button, when the above is on
                skills_hide_maxed = false, -- Drop capped skills from the list; the tab's filter sets it
                rep_standing = 0, -- 0 = every faction, 1..8 = only that FACTION_STANDING_LABEL
                rep_hide_inactive = false, -- Drop what the detail popup moved to Inactive
                currency_hide_empty = false, -- Drop currencies the character holds none of
                show_item_level = true, -- Headline average item level above the stat categories
                show_gear_score = false, -- Headline GearScore above the stat categories
                -- stats_collapsed / stats_order are written by the panel itself, never defaulted:
                -- an empty default table would be shared by every profile that has not set one.
            },
            itemlevel = {
                enabled = true, -- Show item level on gear icons
                font_size = 12,
                font_family = "expressway", -- default|expressway|primary|narrow|skurri|morpheus
                font_outline = "THICKOUTLINE", -- NONE|OUTLINE|THICKOUTLINE (no real bold in 3.3.5a)
                position = "BOTTOM", -- BOTTOM|CENTER|TOP vertical placement on the icon
                show_average = true, -- Average item level on the character/inspect panel
                show_durability = false, -- Durability % on the character panel slots
                show_repair_cost = false, -- Total repair cost of the equipped set in the character window
                tooltip_cvar = false, -- Also set Blizzard's showItemLevel CVar (tooltip line)
                -- Per-context toggles
                bags = true,
                bank = true,
                guildbank = true,
                character = true,
                inspect = true,
                merchant = true,
                trade = true,
                loot = true,
                lootroll = true,
                mail = true,
                auction = true,
            },
            itemownership = {
                enabled = false, -- Show per-character bag, bank and equipped counts in item tooltips
            },
            equipmentcompare = {
                enabled = false, -- Compare equippable items without holding Shift; Ctrl suppresses it
            },
            chatmods = {
                enabled = true, -- Chat enhancements: hide buttons, editbox position, URL copy, chat copy
                linkHoverTooltip = false, -- Show supported chat-link tooltips without holding Alt
                classColorNames = false, -- Class-color player names in every chat type and channel
                editbox = "bottom", -- Editbox position: "top", "bottom", or "middle"
                tabIdleAlpha = 0, -- Tab opacity when not hovered (0 = hidden, 1 = fully visible)
                chatStyle = "none", -- Chat frame background style: "none", "dark", "dragon", "midnight"
                chatBgIdleAlpha = 0, -- Chat style background opacity when idle/mouse away (0 = hidden, 1 = always visible)
                editboxIdleAlpha = 0, -- Editbox minimum opacity when idle (0 = fades with tabs, 1 = always visible)
                editboxStyle = "dark", -- Editbox background style: "none", "dark", "dragon", "midnight"
                vanillaEditbox = false, -- Use the stock chat input appearance instead of the DragonUI one
            },
            bagster = {
                enabled = false, -- All-in-one bag replacement with filtering and search
                money_display = "icons", -- Coin display: "icons" (g/s/c icons) or "text"
                item_scale = 1, -- Target item slot scale (1 = native 37px slot); cell flexes to fill the width
                item_spacing = 2, -- Gap between slots (pitch = 37 + spacing)
                bag_break = 1, -- 0 off, 1 normal↔profession (+keyring block), 2 every bag
                break_space = 1.3, -- Extra rows between bag-break groups
                glow_quality = true, -- Colored ring on uncommon and better items
                glow_quest = true, -- Golden border on quest items
                glow_alpha = 1, -- Quality ring opacity
                show_quality_filter = true, -- Rarity filter dots centered on the bottom band
                tooltip_count = true, -- Total owned (bags + bank) line on item tooltips
            },
            bags_skin = {
                enabled = true -- Experimental retail-style bag window skin
            },
            loot_skin = {
                enabled = true, -- Retail-style skin for the Blizzard loot window
                animated_reflow = true, -- Compact collected loot with animated rows and panel resizing
                auto_hide_empty = false, -- Close the loot window when there is nothing left to loot
                auto_loot_hold = 0, -- Seconds auto-looted rows stay before flying out (0 = at once)
            },
            bagsort = {
                enabled = true, -- Sort bags and bank items with buttons
                bank_fill_from_bags = true, -- Sort bank: top off partial bank stacks from bags first
                lockedSlots = {}, -- Slots excluded from sorting (key format: "bag:slot")
                move_interval = 0.1, -- Delay between item move attempts while sorting
                lock_hotkey = "ALT_LEFT", -- Modifier + mouse button used to lock or unlock a slot
                lock_color = { 0.15, 0.80, 1.00, 0.95 }, -- Tint applied to the locked-slot padlock icon
                reverse_stack = false, -- Stack items from the end so new loot appears at the top
            },
            altmoney = {
                enabled = true, -- Other characters' gold on the bag money tooltip
                show_all_realms = true, -- Include characters from other realms in the list
            },
            unitframe_layers = {
                enabled = false, -- Heal prediction, absorb shields, animated health loss overlays on unit frames
                animated_loss = true, -- Animated red health loss bar on player frame
                builder_spender = false, -- Mana gain/loss glow feedback (experimental)
                missing_health = false -- Show missing health deficit text on health bars
            },
            versioncheck = {
                enabled = true, -- Cross-player version broadcast and update detection
            },
            collections = {
                enabled = true, -- Dedicated Pets & Mounts window opened from the micro menu
            },
            spellbook = {
                enabled = true, -- Modern spellbook window with learned spells, pets, categories, search
                scale = 0.8, -- Scale of the book's content (0.5–1.2); the frame around it stays at 1
                minimized = false, -- One page instead of two
                forceWide = false, -- Two pages kept even where they overflow the screen (content shrinks)
                hidePassives = false, -- Leave passive spells out of the book
                hideUnlearned = false, -- Leave out the grey cards of spells not learned yet
                rankSelector = "flyout", -- Lower ranks: "flyout" side strip or "dropdown" menu under the icon
                rankSelectorShown = true, -- Offer the lower-rank selector on spell cards at all
                highlightUnbound = false, -- Pulse learned spells that sit on no action bar slot
            },
            professions = {
                enabled = true, -- Forever professions window built on Blizzard's TradeSkillFrame
                scale = 1, -- Scale of the whole window (0.6–1.2); its UIPanel slot grows and shrinks with it
                tabScale = 0.9, -- Scale of the side tabs alone (0.5–1), on top of the window's
                micro_button = true, -- Professions button in the micro menu, after Character; it opens the Overview
            },
            worldmap = {
                enabled = true, -- Retail-style world map with breadcrumb navigation and a quest log side panel
                questLog = true, -- Quest log side panel open
                maximized = false, -- Window at its maximized size
                objectives = true, -- The objective lines under each quest title in the side panel
                landmarks = true, -- The client's own landmark pins (battlefield objectives) shown on the map
                fog = true, -- Undiscovered areas drawn dimmed instead of hidden
                entrances = true, -- Dungeon and raid entrance pins on zone maps
                graveyards = true, -- Graveyard pins on zone maps
                flightPoints = true, -- Flight master pins on zone maps
                inns = true, -- Innkeeper pins on zone maps, the hearthstone's inn drawn larger
                coordinates = true, -- Cursor and player coordinates in the canvas corner
                zoneLevels = true, -- Recommended level ranges beside zone names and instance pins
                groupPins = "color", -- Party/raid pins on the world and battlefield maps: "blizzard", "color" or "icon"
                fadeWhenMoving = false, -- Dim the map while you move with the cursor off it
                moveAlpha = 0.4, -- Alpha the map fades to while moving
            },
            hp_low_alert = {
                enabled = true, -- Screen flash and sound when HP drops below threshold
                threshold = 30, -- HP percentage threshold to trigger warning
                soundEnabled = false, -- Play warning sound (repeats every 3 sec)
                flashEnabled = true, -- Flash screen edges red
                flashColor = { r = 1, g = 0, b = 0 }, -- Color of the screen edge flash
                useClassColor = false, -- Use player class color instead of flashColor
                flashOpacity = 0.35, -- Max alpha of the flash (0.0–1.0)
                flashExtent = 40,  -- Pixels from screen edges toward center
            },
            addonmanager = {
                enabled = true, -- AddOns button in the Esc menu opening the in-game addon list
                scale = 1, -- Addon list window scale on top of the UI scale
            },
            mail = {
                enabled = true, -- Retail-style mail window with the Open All button
            },
            taxiframe = {
                enabled = true, -- Retail-style flight master map window
            },
        },

        -- LAYOUT PRESETS (user-saved UI snapshots within this profile)
        presets = {},

        -- POSITION PRESETS (edit-mode element positions only)
        positionPresets = {}
    }
};

-- Temporary profile placeholder (replaced by AceDB in core.lua:OnInitialize)
addon.db = {
    profile = addon.defaults and addon.defaults.profile or {},
    global = addon.defaults and addon.defaults.global or {}
};

-- Duplicates addon.DeepCopy on purpose: database.lua loads before core/api.lua defines it.
local function deepCopy(source, target)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if not target[key] then
                target[key] = {}
            end
            deepCopy(value, target[key])
        else
            target[key] = value
        end
    end
end

-- Populate temporary profile with defaults
if defaults and defaults.profile then
    deepCopy(defaults.profile, addon.db.profile);
end
if defaults and defaults.global then
    deepCopy(defaults.global, addon.db.global);
end

-- Export defaults for use in core.lua
addon.defaults = defaults;

-- Database accessors
function addon:GetConfigValue(section, key, subkey)
    if subkey then
        return self.db.profile[section][key][subkey];
    elseif key then
        return self.db.profile[section][key];
    else
        return self.db.profile[section];
    end
end

function addon:SetConfigValue(section, key, subkey, value)
    if subkey then
        self.db.profile[section][key][subkey] = value;
    elseif key then
        self.db.profile[section][key] = value;
    else
        self.db.profile[section] = value;
    end
end
