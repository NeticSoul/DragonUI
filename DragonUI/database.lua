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
        combuctorCache = {} -- Per-character bank snapshot (realm|name keys); used by combuctor module
    },
    profile = {
        version = 1,
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
                posY = 143
            },
            playerCastbar = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 200
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
                posY = 64
            },
            bottombarright = {
                anchor = "BOTTOM",
                posX = 0,
                posY = 102
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
                posY = 20,
                tooltip_position = "TOP"
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
                custom_position = false
            },
            positionPresetPanel = {
                anchor = "TOP",
                posX = 0,
                posY = 144,
                relativePoint = "CENTER",
                custom_position = false
            }
        },
        -- Quest Tracker
        questtracker = {
            anchor = "TOPRIGHT",
            x = -210,
            y = -255,
            show_header = true,
            font_size = 12,      -- Point size for quest tracker text (WoW default: 11)
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
        },
        -- ACTIONBAR SETTINGS
        mainbars = {
            -- Per-bar layout (nested sub-tables with rows/columns/buttons_shown)
            player = {
                rows = 1,
                columns = 12,
                buttons_shown = 12,
                change_button_order = false,
                button_order = "top_left"
            },
            left = {
                horizontal = false,
                rows = 12,
                columns = 1,
                buttons_shown = 12,
                change_button_order = false,
                button_order = "top_left"
            },
            right = {
                horizontal = false,
                rows = 12,
                columns = 1,
                buttons_shown = 12,
                change_button_order = false,
                button_order = "top_left"
            },
            bottom_left = {
                rows = 1,
                columns = 12,
                buttons_shown = 12,
                change_button_order = false,
                button_order = "top_left"
            },
            bottom_right = {
                rows = 1,
                columns = 12,
                buttons_shown = 12,
                change_button_order = false,
                button_order = "top_left"
            },

            -- Global button spacing (gap between buttons in pixels)
            button_spacing = 7,

            -- Per-bar scales
            scale_actionbar = 0.9,
            scale_rightbar = 0.9,
            scale_leftbar = 0.9,
            scale_bottomleft = 0.9,
            scale_bottomright = 0.9,
            scale_vehicle = 1
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
            micro_show_on_hover = false,
            micro_show_in_combat = false,
            micro_hide_in_combat = false,
            micro_visibility_logic = "and",
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
                icon_spacing = 15 -- Gap between icons
            },

            -- Normal colored icons configuration  
            normal = {
                scale_menu = 0.9,
                x_position = -113,
                y_position = -53,
                icon_spacing = 26
            }
        },

        bags = {
            scale = 1,
            x_position = 1,
            y_position = 41
        },

        xprepbar = {
            -- Style: "dragonflightui" (custom bars) or "retailui" (atlas reskin)
            style = "dragonflightui",
            -- Bar dimensions
            bar_width = 466,
            bar_height_dfui = 14,
            bar_height_retailui = 9,
            -- Positioning offsets (used by both styles)
            bothbar_offset = 39,
            singlebar_offset = 24,
            nobar_offset = 18,
            repbar_abovexp_offset = 16,
            repbar_offset = 2,
            dual_bar_gap = 2,
            -- Configurable scales for the bars
            expbar_scale = 1.0,
            repbar_scale = 1.0,
            -- Rested XP
            show_rested_bar = true,
            show_rested_mark = true,
            -- Text display
            always_show_text = false,
            show_xp_percent = false,
            show_rep_text_on_hover = true,
            -- Hover/combat visibility (shared by both bars, see core/visibility_fade.lua)
            show_on_hover = false,
            show_in_combat = false,
            hide_in_combat = false,
            visibility_logic = "and",
        },

        style = {
            gryphons = 'new',
            xpbar = 'dragonflightui',
            exhaustion_tick = true -- Show exhaustion tick (on by default)
        },

        compatibility = {
            d3d9ex_warning_seen = false,
        },

        buttons = {
            only_actionbackground = true,
            hide_main_bar_background = false,
            count = {
                show = true
            },
            hotkey = {
                show = true,
                range = true,
                shadow = {0, 0, 0, 1},
                font = {_arialn, 12, "OUTLINE"}
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
                y_offset = -58, -- Additional Y offset for fine-tuning position
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
            }
        },

        -- MINIMAP SETTINGS
        minimap = {
            scale = 1,
            border_alpha = 1,
            blip_skin = true, -- true = new/modern style, false = old/classic Blizzard style
            tracking_icons = true,
            zoom_buttons = false,
            calendar = true,
            clock = true,
            clock_font_size = 12,
            player_arrow_size = 40,
            zonetext_font_size = 12,
            mail_icon_x = -4,
            mail_icon_y = -5,
            settings_button_angle = 203,
            collector_enabled = true,
            collector_style = "dragonui",
            animated_border_enabled = false,
            animated_border_scale = 0.9,
            animated_border_preset = "drg_preset_01",
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

        --  BUFFS SETTINGS (NEW)
        buffs = {
            enabled = true,
            show_toggle_button = true,
            buffs_hidden = false,
            separate_weapon_enchants = false,
            buff_horizontal_gap = 0,
            debuff_horizontal_gap = 0
        },

        -- CASTBAR SETTINGS
        castbar = {
            enabled = true,
            scale = 1,
            text_mode = "simple",
            precision_time = 1,
            precision_max = 1,
            sizeX = 256,
            sizeY = 16,
            showIcon = false,
            sizeIcon = 27,
            holdTime = 0.3,
            holdTimeInterrupt = 0.8,

            -- LATENCY INDICATOR (PLAYER ONLY)
            latency = {
                enabled = false,
                color = { r = 0.9, g = 0.5, b = 0.2 },
                alpha = 0.45,
            },

            -- TARGET CASTBAR SETTINGS
            target = {
                enabled = true,
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
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                anchorFrame = 'TargetFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM',
                showTicks = false
            },

            -- FOCUS CASTBAR SETTINGS
            focus = {
                enabled = true,
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
                holdTime = 0.3,
                holdTimeInterrupt = 0.8,
                anchorFrame = 'FocusFrame',
                anchor = 'TOP',
                anchorParent = 'BOTTOM',
                showTicks = false
            }
        },

        -- CHAT SETTINGS
        chat = {
            enabled = true, -- Disabled by default to avoid interfering with the original chat
            scale = 1.0,
            x_position = 42, -- X relative to BOTTOM LEFT
            y_position = 35, -- Y relative to BOTTOM LEFT
            size_x = 295, -- Chat width
            size_y = 120 -- Chat height
        },

        -- UNIT FRAMES SETTINGS
        unitframe = {
            scale = 1.0, -- Global scale for all unit frames
            player = {
                enabled = true,
                breakUpLargeNumbers = true,
                scale = 1.0,
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                textFormat = "both",
                showHealthTextAlways = false,
                showManaTextAlways = false,
                dragon_decoration = "none",
                alwaysShowAlternateManaText = false,
                alternateManaFormat = "both",
                show_runes = true, -- DK rune display (used by player.lua)
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
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                enableNumericThreat = true,
                enableThreatGlow = true,
                show_name_background = true,
                scale = 1.0,
                -- Also fades Target of Target and the target cast bar (see target_style.lua)
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            focus = {
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                show_buff_debuff = true,
                show_name_background = true,
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
                enableThreatGlow = false,
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
                breakUpLargeNumbers = true,
                textFormat = 'both',
                showHealthTextAlways = false,
                showManaTextAlways = false,
                orientation = 'vertical',
                padding_vertical = 30,
                padding_horizontal = 50,
                scale = 1.0,
                override = false,
                anchor = 'TOPLEFT',
                anchorParent = 'TOPLEFT',
                x = 10,
                y = -200,
                show_on_hover = false,
                show_in_combat = false,
                visibility_logic = "and",
            },
            tot = {
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                scale = 1.0,
                x = -27,
                y = -14,
                textFormat = 'numeric',
                breakUpLargeNumbers = false,
                showHealthTextAlways = false,
                showManaTextAlways = false,
                override = false,
                anchor = 'BOTTOMRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                anchorFrame = 'TargetFrame'
            },
            fot = {
                classcolor = false,
                classPortrait = false, -- Show class icon instead of character portrait
                alternativeClassIcons = false, -- Use DragonUI alternative class icons for class portraits
                scale = 1.0,
                x = -27,
                y = -14,
                textFormat = 'numeric',
                breakUpLargeNumbers = false,
                showHealthTextAlways = false,
                showManaTextAlways = false,
                override = false,
                anchor = 'BOTTOMRIGHT',
                anchorParent = 'BOTTOMRIGHT',
                anchorFrame = 'FocusFrame'
            },
            boss = {
                enabled = true,
                scale = 1.0,
                classcolor = false,
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
            petbar = {
                enabled = true -- Apply DragonUI pet bar positioning and styling
            },
            multicast = {
                enabled = true -- Apply DragonUI multicast (totem/possess) bar positioning and styling
            },
            micromenu = {
                enabled = true -- Apply DragonUI micro menu and bags system styling and positioning
            },
            mainbars = {
                enabled = true -- Apply DragonUI main action bars, status bars (XP/Rep), scaling, and positioning system
            },
            minimap = {
                enabled = true -- Apply DragonUI minimap enhancements including custom styling, positioning, tracking icons, and calendar
            },
            MinimapDecorations = {
                enabled = true -- Native animated minimap border decorations module
            },
            buffs = {
                enabled = true -- Enable DragonUI buff frame with custom styling, positioning, and toggle button functionality
            },
            auraborders = {
                enabled = true, -- Modern DF-style borders on buff/debuff icons (player/target/focus)
                buff_color = { r = 0.2, g = 0.2, b = 0.2 }, -- grayish neutral for buff borders; debuffs use dispel-type color
                custom_border = true -- border style: true = rounded (custom texture overlay), false = square (solid lines)
            },
            keybinding = {
                enabled = true, -- Enable LibKeyBound integration for intuitive keybinding (hover + key press)
                auto_register_action_buttons = true -- Automatically make action buttons bindable
            },
            questtracker = {
                enabled = true -- Enable DragonUI quest tracker positioning and styling
            },
            keypress = {
                enabled = false -- Fire action-bar abilities on key down instead of key release (SnowfallKeyPress-style)
            },
            darkmode = {
                enabled = false, -- Apply darker tinted textures to UI chrome
                intensity_preset = 3, -- 1 = Light, 2 = Medium, 3 = Dark
                use_custom_color = false, -- Override presets with custom color
                custom_color = { r = 0.15, g = 0.15, b = 0.15 } -- Custom tint RGB
            },
            nameplates = {
                enabled = true,
                barWidth = 150, -- ~Blizzard plate width
                barHeight = 9, -- height of the nameplate in pixels
                fontSize = 2, -- Scale 1-10, maps to name/HP font px
                nameFont = "primary", -- font for name/level text (primary, actionbar, narrow, arial, system)
                showHealthPercent = true,
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
                showPartyRaidCastBars = false, -- show cast bars on party/raid member nameplates
                castBarHeight = 9, -- height of the cast bar in pixels
                castBarGap = 3, -- vertical gap between health, power, and cast bars
                showCastBarSpellName = false, -- show the spell name text on the cast bar
                castBarSpellNameFontSize = 9, -- font size for the cast bar spell name text
                castBarSpellNameOffsetX = 0, -- horizontal offset for the cast bar spell name text
                castBarSpellNameOffsetY = 0, -- vertical offset for the cast bar spell name text
                threatGlow = true, -- show threat glow indicator (colored border)
                tankMode = false, -- invert threat colors for a tank perspective (holding aggro = green)
                raidMarkHealthColor = false, -- tint health bar by raid marker, allies and enemies alike
                showTargetHighlight = true,
                showTargetArrows = false,
                showDebuffs = true,
                maxDebuffs = 5,
                debuffIconSize = 24, -- debuff icon size in pixels
                showDebuffCooldown = true, -- show remaining debuff time text on icons
                debuffCooldownSwipe = true, -- also show a radial cooldown swipe on debuff icons
                debuffCooldownSwipeStyle = "squareSwirl", -- "vertical" | "pie" | "squareSwirl"
                debuffCooldownFontSize = 10, -- font size for debuff remaining time text
                debuffCooldownTextAnchor = "center", -- "center" | "topleft" | "topright" | "bottomleft" | "bottomright"
                debuffOnlyTargetFocus = false, -- only show debuffs on target/focus plates
                debuffOnlyMine = false, -- only show debuffs the player applied
                debuffFilterMode = "all", -- "all" | "whitelist" | "blacklist"
                debuffFilterList = "", -- comma-separated spell IDs for whitelist/blacklist
                debuffHighlightCC = false, -- colored border for crowd-control/lockout debuffs (curated spell list)
                debuffOffsetX = 0, -- horizontal offset for the debuff icon row
                debuffOffsetY = 0, -- vertical offset for the debuff icon row
                showDebuffPositionDebug = false, -- persistent debug box showing debuff row bounds
                showRaidMarkers = true, -- show raid target markers (skull, cross, etc.)
                showEliteIcon = true, -- show elite/rare dragon icon on nameplates
                eliteIconStyle = "dragon", -- "dragon" | "star" (star uses *-icon-old textures)
                showComboPoints = false, -- show combo points on target nameplate
                showTotemIcons = false, -- show totem icon on shaman totem nameplates
                totemIconPosition = "top", -- "top" | "left" | "right"
                totemIconOnly = false, -- hide the totem nameplate entirely; show only the totem icon
                showTotemTimer = true, -- show remaining life on own totems (requires GetTotemInfo data)
                totemNormalModeList = "", -- comma-separated exact totem names forced to render as a plain plate (no icon)
                centerNameOnly = false, -- hide level/health % and center the unit name
                showLevelInName = false, -- show the level in the nameplate
                showLevelOnHover = false, -- level on hover+target; false = target only
                showLevelAlways = true, -- always show level bracket on any resolvable plate
                levelTextFormat = "plain", -- "brackets" | "parentheses" | "plain"
                nameReactionColors = false, -- tint name text with health-bar reaction color
                enemyNameClassColors = false, -- class colors for enemy player name text
                friendlyPlayerColor = { r = 0, g = 0, b = 1 }, -- default friendly player color (vanilla blue)
                friendlyNPCColor = { r = 0, g = 1, b = 0 }, -- default friendly NPC color (green)
                partyClassColors = false, -- use class colors for party members instead of friendlyPlayerColor
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
                friendlyNPCNameOnlyTitle = false, -- show <Title/Occupation> subtitle for friendly NPCs (awesome_wotlk only)
                enemyPlayerClassColors = false, -- use class colors for enemy player nameplates (ShowClassColorInNameplate)
                disableNonTargetFade = false, -- when true, target/non-target use the same full opacity
                opacityNonTarget = 0.5, -- default non-target opacity
                opacityFullNoTarget = true, -- when no target exists, use full target opacity
                opacityFullParty = false, -- always show party/raid member nameplates at full opacity
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
            },
            tooltip = {
                enabled = true, -- Enhanced tooltip styling with class colors
                class_colored_border = true, -- Color tooltip border by class/reaction
                class_colored_name = true, -- Color unit name by class
                target_of_target = true, -- Show target-of-target line
                health_bar = true, -- Show health bar on tooltip
                anchor_cursor = false -- Anchor tooltip to cursor
            },
            itemquality = {
                enabled = true, -- Color item borders by quality in bags, character panel, bank, merchant
                min_quality = 2 -- Minimum quality to show (2 = Uncommon/green)
            },
            chatmods = {
                enabled = true, -- Chat enhancements: hide buttons, editbox position, URL copy, chat copy
                editbox = "bottom", -- Editbox position: "top", "bottom", or "middle"
                tabIdleAlpha = 0, -- Tab opacity when not hovered (0 = hidden, 1 = fully visible)
                chatStyle = "none", -- Chat frame background style: "none", "dark", "dragon", "nocturne"
                chatBgIdleAlpha = 0, -- Chat style background opacity when idle/mouse away (0 = hidden, 1 = always visible)
                editboxIdleAlpha = 0, -- Editbox minimum opacity when idle (0 = fades with tabs, 1 = always visible)
                editboxStyle = "dark", -- Editbox background style: "none", "dark", "dragon", "nocturne"
            },
            combuctor = {
                enabled = false -- All-in-one bag replacement with filtering and search
            },
            bags_skin = {
                enabled = true -- Experimental retail-style bag window skin
            },
            bagsort = {
                enabled = true, -- Sort bags and bank items with buttons
                bank_fill_from_bags = true, -- Sort bank: top off partial bank stacks from bags first
                lockedSlots = {}, -- Slots excluded from sorting (key format: "bag:slot")
                move_interval = 0.1, -- Delay between item move attempts while sorting
                lock_hotkey = "ALT_LEFT", -- Modifier + mouse button used to lock or unlock a slot
                lock_color = { 0.15, 0.80, 1.00, 0.95 } -- Tint applied to the locked-slot padlock icon
            },
            unitframe_layers = {
                enabled = false, -- Heal prediction, absorb shields, animated health loss overlays on unit frames
                animated_loss = true, -- Animated red health loss bar on player frame
                builder_spender = false, -- Mana gain/loss glow feedback (experimental)
                missing_health = false -- Show missing health deficit text on health bars
            },
            versioncheck = {
                enabled = true, -- Cross-player version broadcast and update detection
            }
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

-- Recursive table copy (preserves existing keys in target)
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
