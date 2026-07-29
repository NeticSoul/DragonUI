local addon = select(2, ...)
local NP = addon.Nameplates

-- Nameplates: texture paths, sizes, colors, mappings.

NP.const = {
    MINA_TEX = "Interface\\AddOns\\DragonUI\\Textures\\Nameplates\\",
    CAST_TEX_PATH = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\",
    CAST_TEX_ATLAS = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\uicastingbar2x",
    CAST_SHIELD_UV = { 0.000976562, 0.0742188, 0.796875, 0.970703 },
    CAST_SHIELD_SIZE_W = 1.6,
    CAST_SHIELD_SIZE_H = 1.8,
    CAST_SHIELD_OFFSET_X = 0,
    CAST_SHIELD_OFFSET_Y = -2,
    CAST_NOTINT_ICON_SCALE = 1,
    CAST_NOTINT_ICON_OFFSET_X = -3,
    CAST_NOTINT_ICON_OFFSET_Y = 7,
    CAST_TEX_STANDARD = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\CastingBarStandard2",
    CAST_TEX_INTERRUPTED = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\CastingBarInterrupted2",
    CAST_TEX_CHANNEL = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\CastingBarChannel-Plate",
    CAST_TEX_SPARK = "Interface\\AddOns\\DragonUI\\Textures\\Castbar\\CastingBarSpark",
    CAST_COLOR_STANDARD = { 1, 0.7, 0 },
    CAST_COLOR_CHANNEL = { 1, 1, 1 },
    CAST_INTERRUPT_HOLD = 0.3,
    CAST_INTERRUPT_FADE = 0.5,
    CAST_MONITOR_MIN_CONFIDENCE = 60,
    CAST_MONITOR_ACTIVE_MIN_CONFIDENCE = 50,
    CAST_WARMUP_MIN_AGE = 0.3,
    CAST_WARMUP_COOLDOWN = 1.0,
    LEVEL_TEXT_SETTLE = 0.15,
    CAST_PLAYER_NAME_CONFIDENCE = 70,
    CAST_NAME_SCORE_MIN = 32,
    CAST_NAME_SCORE_NOHINT_MIN = 44,
    CAST_NAME_SCORE_GAP = 8,
    CAST_NAME_SCORE_CENTER_BONUS = 30,
    CAST_NAME_SCORE_DAMAGED_BONUS = 10,
    CAST_NAME_SCORE_MATCHED_UNIT_BONUS = 35,
    CAST_NAME_SCORE_MONITOR_GUID_BONUS = 40,
    -- Aggressive off-target only; safe mode ignores these.
    CAST_AGGRESSIVE_NAME_BASE_BONUS = 50,
    CAST_AGGRESSIVE_AUTHORITATIVE_BONUS = 10000,
    CAST_AGGRESSIVE_GUID_CLAIM_PENALTY = 200,
    CAST_AGGRESSIVE_NAME_SCORE_GAP = 0,
    CAST_AGGRESSIVE_MONITOR_MIN_CONFIDENCE = 50,
    CAST_AGGRESSIVE_WARMUP_MIN_AGE = 0.1,
    GUID_CONFIDENCE = {
        LEGACY = 50,
        TOKEN_TARGET = 100,
        TOKEN_MOUSEOVER = 90,
        TOKEN_FOCUS = 90,
        NAMEPLATE_TOKEN = 85,
        ARENA_TOKEN = 88,
        GROUP_TARGET = 70,
        AURA_HINT = 60,
        RAID_ICON = 60,
        CLEU_WARMUP = 45,
        NAME_UNIQUE = 40,
    },
    GUID_LOCK_THRESHOLD = 85,
    GUID_LOCK_TTL = {
        TOKEN_TARGET = 2.0,
        TOKEN_MOUSEOVER = 1.0,
        TOKEN_FOCUS = 1.0,
        NAMEPLATE_TOKEN = 1.0,
        ARENA_TOKEN = 1.0,
    },
    HEALTH_MATCH_TOLERANCE = 0.02,
    SCAN_INTERVAL = 0.25,
    MARKER_BORDER = [[Interface\Tooltips\Nameplate-Border]],
    MARKER_FLASH = [[Interface\TargetingFrame\UI-TargetingFrame-Flash]],
    THREAT_GLOW_W = 4,
    THREAT_GLOW_H = 6.5,
    THREAT_GLOW_Y = 0.6,
    RAID_MARKER_SIZE = 24,
    RAID_MARKER_OFFSET_X = 0,
    RAID_MARKER_OFFSET_Y = 41,
    RAID_MARKER_OFFSET_Y_WITH_COMBO = 53,
    RAID_MARKER_SIDE_GAP = 3, -- gap past bar edge when marker sits beside the bar
    RAID_MARKER_OFFSET_Y_WITH_DEBUFFS = 8.5,
    DEBUFF_HOST_OFFSET_Y = 2,
    DEBUFF_HOST_OFFSET_Y_WITH_COMBO = 12,
    COMBO_TEX = "Interface\\AddOns\\DragonUI\\Textures\\Nameplates\\combo-",
    COMBO_ICON_W = 64,
    COMBO_ICON_H = 32,
    TOTEM_ICON_W = 26,
    TOTEM_ICON_H = 26,
    TOTEM_ICON_OFFSET_X = 0,
    TOTEM_ICON_OFFSET_Y = 40,
    TOTEM_ICON_RIGHT_OFFSET_X = 30,
    TOTEM_ICON_RIGHT_OFFSET_Y = 7,
    TOTEM_ICON_LEFT_OFFSET_X = -30,
    TOTEM_ICON_LEFT_OFFSET_Y = 7,
    ELITE_ICON_TEX_BASE = "Interface\\AddOns\\DragonUI\\Textures\\Nameplates\\elite-icon",
    RARE_ICON_TEX_BASE = "Interface\\AddOns\\DragonUI\\Textures\\Nameplates\\rare-icon",
    TEX_COORD_EPS = 0.025,
    -- Stagger token-based threat checks across buckets; target/focus stay full-rate.
    THREAT_BUDGET_BUCKETS = 4,
    -- Max nameplate token probes per engine tick.
    TOKEN_PROBE_PLATES_PER_TICK = 3,
    -- Max BuildPlateState refreshes per tick; caps mass-refresh spikes (FruitPlates pattern).
    FULL_REFRESH_PLATES_PER_TICK = 8,
}

local C = NP.const

C.TOTEM_TEX = C.MINA_TEX .. "Totem\\"

C.QUEST_ICON_TEX = {
    pointer = C.MINA_TEX .. "Quests\\quest_pointer",
    sword = C.MINA_TEX .. "Quests\\Kill\\kill_sword",
    skull = C.MINA_TEX .. "Quests\\Kill\\kill_skull",
    elite = C.MINA_TEX .. "Quests\\Kill\\kill_elite",
    bag = C.MINA_TEX .. "Quests\\Loot\\loot_bag",
    chest = C.MINA_TEX .. "Quests\\Loot\\loot_chest",
}

C.NAMEPLATE_FONT_MAP = {
    primary = "PRIMARY",
    actionbar = "ACTIONBAR",
    narrow = "NARROW",
    arial = "ARIALN",
}

C.EXCLUDED_FRAME_NAMES = {
    ["WorldFrameDragOverlay"] = true,
    ["BNToastFrame"] = true,
}

C.CLASS_BY_BAR_COLOR = {
    [000] = "FRIENDLY_PLAYER",
    [019] = "DEATHKNIGHT",
    [058] = "DRUID",
    [089] = "HUNTER",
    [085] = "MAGE",
    [065] = "PALADIN",
    [110] = "PRIEST",
    [106] = "ROGUE",
    [044] = "SHAMAN",
    [057] = "WARLOCK",
    [068] = "WARRIOR",
}

C.AGGRO_COLORS = {
    tanking = { 1.0, 0.0, 0.0 },
    losing = { 1.0, 0.6, 0.0 },
    gaining = { 1.0, 1.0, 0.0 },
    -- Tank-mode perspective: holding aggro is safe; losing aggro on an
    -- engaged hostile unit is the warning condition.
    tankHolding = { 0.0, 1.0, 0.0 },
    tankWarning = { 1.0, 1.0, 0.0 },
    tankLost = { 1.0, 0.0, 0.0 },
}

C.RAID_MARK_HEALTH_COLORS = {
    STAR = { 0.85, 0.81, 0.27 },
    CIRCLE = { 0.93, 0.51, 0.06 },
    DIAMOND = { 0.70, 0.06, 0.84 },
    TRIANGLE = { 0.14, 0.66, 0.14 },
    MOON = { 0.60, 0.75, 0.85 },
    SQUARE = { 0.00, 0.64, 1.00 },
    CROSS = { 0.82, 0.18, 0.18 },
    SKULL = { 0.89, 0.83, 0.74 },
}

C.PLATE_CLASS_TEXCOORDS = {
    elite     = {0.001953125, 0.314453125, 0.322265625, 0.630859375},
    rare      = {0.00390625, 0.31640625, 0.64453125, 0.953125},
    rareelite = {0.001953125, 0.388671875, 0.001953125, 0.31835937},
}

C.TOTEM_EXACT = {
    ["Tremor Totem"] = "Tremor Totem",
    ["Cleansing Totem"] = "Cleansing Totem",
    ["Grounding Totem"] = "Grounding Totem",
    ["Windfury Totem"] = "Windfury Totem",
    ["Wrath of Air Totem"] = "Wrath of Air Totem",
    ["Earthbind Totem"] = "Earthbind Totem",
    ["Mana Tide Totem"] = "Mana Tide Totem",
    ["Sentry Totem"] = "Sentry Totem",
    ["Fire Elemental Totem"] = "Fire Elemental Totem",
    ["Earth Elemental Totem"] = "Earth Elemental Totem",
    ["Nature Resistance Totem VI"] = "Nature Resistance Totem VI",
    ["Frost Resistance Totem VI"] = "Frost Resistance Totem VI",
    ["Fire Resistance Totem VI"] = "Fire Resistance Totem VI",
    ["Searing Totem X"] = "Searing Totem X",
    ["Magma Totem VII"] = "Magma Totem VII",
    ["Fire Nova Totem IX"] = "Fire Nova Totem IX",
    ["Flametongue Totem VIII"] = "Flametongue Totem VIII",
    ["Totem of Wrath IV"] = "Totem of Wrath IV",
    ["Stoneclaw Totem X"] = "Stoneclaw Totem X",
    ["Stoneskin Totem X"] = "Stoneskin Totem X",
    ["Strength of Earth Totem VIII"] = "Strength of Earth Totem VIII",
    ["Healing Stream Totem IX"] = "Healing Stream Totem IX",
    ["Mana Spring Totem VIII"] = "Mana Spring Totem VIII",
}

C.TOTEM_ALIASES = {
    ["Healing Stream Totem"] = "Healing Stream Totem IX",
    ["Searing Totem"] = "Searing Totem X",
    ["Strength of Earth"] = "Strength of Earth Totem VIII",
}

-- Build localized NPC names from WotLK spell data at runtime. Each spell ID
-- maps its localized GetSpellInfo name to an existing DragonUI texture.
C.TOTEM_SPELL_TEXTURES = {
    { 8075, "Strength of Earth Totem VIII" },
    { 8071, "Stoneskin Totem X" },
    { 5730, "Stoneclaw Totem X" },
    { 2484, "Earthbind Totem" },
    { 8143, "Tremor Totem" },
    { 2062, "Earth Elemental Totem" },
    { 3599, "Searing Totem X" },
    { 8181, "Frost Resistance Totem VI" },
    { 1535, "Fire Nova Totem IX" },
    { 8190, "Magma Totem VII" },
    { 8227, "Flametongue Totem VIII" },
    { 2894, "Fire Elemental Totem" },
    { 30706, "Totem of Wrath IV" },
    { 10595, "Nature Resistance Totem VI" },
    { 8512, "Windfury Totem" },
    { 8177, "Grounding Totem" },
    { 6495, "Sentry Totem" },
    { 3738, "Wrath of Air Totem" },
    { 5394, "Healing Stream Totem IX" },
    { 5675, "Mana Spring Totem VIII" },
    { 8184, "Fire Resistance Totem VI" },
    { 16190, "Mana Tide Totem" },
    { 8170, "Cleansing Totem" },
}

C.TOTEM_CREATURE_TERMS = {
    enUS = { "Totem", "totem" },
    deDE = { "Totem", "totem" },
    esES = { "Tótem", "tótem", "Totem", "totem" },
    esMX = { "Tótem", "tótem", "Totem", "totem" },
    frFR = { "Totem", "totem" },
    ptBR = { "Totem", "totem" },
    ruRU = { "Тотем", "тотем" },
    koKR = { "토템" },
    zhCN = { "图腾" },
    zhTW = { "圖騰" },
}

C.TOTEM_SUBSTRING = {
    { "wrath of air", "Wrath of Air Totem" },
    { "cólera del aire", "Wrath of Air Totem" },
    { "ira del aire", "Wrath of Air Totem" },
    { "totem of wrath", "Totem of Wrath IV" },
    { "tótem de cólera", "Totem of Wrath IV" },
    { "fire elemental", "Fire Elemental Totem" },
    { "elemental de fuego", "Fire Elemental Totem" },
    { "earth elemental", "Earth Elemental Totem" },
    { "elemental de tierra", "Earth Elemental Totem" },
    { "nature resistance", "Nature Resistance Totem VI" },
    { "resistencia a la naturaleza", "Nature Resistance Totem VI" },
    { "frost resistance", "Frost Resistance Totem VI" },
    { "resistencia a la escarcha", "Frost Resistance Totem VI" },
    { "fire resistance", "Fire Resistance Totem VI" },
    { "resistencia al fuego", "Fire Resistance Totem VI" },
    { "healing stream", "Healing Stream Totem IX" },
    { "tótem de sanación", "Healing Stream Totem IX" },
    { "totem de sanación", "Healing Stream Totem IX" },
    { "mana spring", "Mana Spring Totem VIII" },
    { "fuente de maná", "Mana Spring Totem VIII" },
    { "strength of earth", "Strength of Earth Totem VIII" },
    { "fuerza de la tierra", "Strength of Earth Totem VIII" },
    { "flametongue", "Flametongue Totem VIII" },
    { "lengua de fuego", "Flametongue Totem VIII" },
    { "fire nova", "Fire Nova Totem IX" },
    { "nova de fuego", "Fire Nova Totem IX" },
    { "stoneclaw", "Stoneclaw Totem X" },
    { "garra de piedra", "Stoneclaw Totem X" },
    { "stoneskin", "Stoneskin Totem X" },
    { "piel de piedra", "Stoneskin Totem X" },
    { "searing", "Searing Totem X" },
    { "abrasador", "Searing Totem X" },
    { "magma", "Magma Totem VII" },
    { "tremor", "Tremor Totem" },
    { "cleansing", "Cleansing Totem" },
    { "limpieza", "Cleansing Totem" },
    { "grounding", "Grounding Totem" },
    { "aterramiento", "Grounding Totem" },
    { "windfury", "Windfury Totem" },
    { "furia del viento", "Windfury Totem" },
    { "earthbind", "Earthbind Totem" },
    { "ligazón terrestre", "Earthbind Totem" },
    { "mana tide", "Mana Tide Totem" },
    { "marea de maná", "Mana Tide Totem" },
    { "sentry", "Sentry Totem" },
    { "centinela", "Sentry Totem" },
}

-- Pet/clone cast blacklist (Hide Pet Castbar); per-locale names, npcID table when GUID available.
C.HIDE_PET_CAST_NAMES = {
    -- enUS (also serves ptBR)
    ["Shadowfiend"] = true,
    ["Spirit Wolf"] = true,
    ["Water Elemental"] = true,
    ["Treant"] = true,
    ["Venomous Snake"] = true,
    ["Viper"] = true,
    ["Army of the Dead Ghoul"] = true,
    ["Risen Ghoul"] = true,
    ["Mirror Image"] = true,
    ["Frostwing Whelp"] = true,
    ["Ebon Gargoyle"] = true,
    -- deDE
    ["Schattengeist"] = true,
    ["Geisterwolf"] = true,
    ["Wasserelementar"] = true,
    ["Giftige Schlange"] = true,
    ["Armee der Toten"] = true,
    ["Auferstandener Ghul"] = true,
    ["Spiegelbild"] = true,
    ["Frostschwingenwelpe"] = true,
    -- esES / esMX
    ["Maligno de las Sombras"] = true,
    ["Espíritu de lobo"] = true,
    ["Elemental de agua"] = true,
    ["Antárbol"] = true,
    ["Culebra venenosa"] = true,
    ["Víbora"] = true,
    ["Ejército de muertos"] = true,
    ["Necrófago resucitado"] = true,
    ["Reflejo exacto"] = true,
    ["Vástago Alaescarcha"] = true,
    ["Gárgola de ébano"] = true,
    -- frFR
    ["Ombrefiel"] = true,
    ["Esprit du loup"] = true,
    ["Elémentaire d’eau"] = true,
    ["Tréant"] = true,
    ["Serpent venimeux"] = true,
    ["Vipère"] = true,
    ["Armée des morts"] = true,
    ["Goule ressuscitée"] = true,
    ["Image miroir"] = true,
    ["Dragonnet Aile-de-givre"] = true,
    ["Gargouille d’ébène"] = true,
    -- ruRU
    ["Исчадие Тьмы"] = true,
    ["Дух волка"] = true,
    ["Элементаль воды"] = true,
    ["Древень"] = true,
    ["Ядовитая змея"] = true,
    ["Гадюка"] = true,
    ["Войско мертвых"] = true,
    ["Восставший вурдалак"] = true,
    ["Зеркальное изображение"] = true,
    ["Ледокрылый дракончик"] = true,
    ["Вороная горгулья"] = true,
    -- koKR
    ["어둠의 마귀"] = true,
    ["늑대 정령"] = true,
    ["물의 정령"] = true,
    ["나무정령"] = true,
    ["살무사"] = true,
    ["독사"] = true,
    ["사자의 군대"] = true,
    ["되살아난 구울"] = true,
    ["복제된 환영"] = true,
    ["서리날개 새끼용"] = true,
    -- zhCN
    ["暗影魔"] = true,
    ["幽灵狼"] = true,
    ["水元素"] = true,
    ["树人"] = true,
    ["剧毒蛇"] = true,
    ["毒蛇"] = true,
    ["亡者大军"] = true,
    ["复活的食尸鬼"] = true,
    ["镜像"] = true,
    ["霜翼幼龙"] = true,
    -- zhTW
    ["暗影惡魔"] = true,
    ["幽靈狼"] = true,
    ["樹人"] = true,
    ["響尾蛇"] = true,
    ["亡靈大軍"] = true,
    ["復活的食屍鬼"] = true,
    ["鏡像"] = true,
    ["霜翼幼龍"] = true,
}

-- npcID layer for same summons when GUID is available (name table covers no-GUID case).
C.HIDE_PET_CAST_NPCIDS = {
    [31216] = true, -- Mirror Image (mage)
    [510]   = true, -- Water Elemental (mage)
    [19668] = true, -- Shadowfiend (priest)
    [1964]  = true, -- Treant (druid, Force of Nature)
    [29264] = true, -- Spirit Wolf (shaman, Feral Spirit)
    [24207] = true, -- Army of the Dead Ghoul (death knight)
    [26125] = true, -- Ghoul / Risen Ghoul (death knight, Raise Dead)
    [19833] = true, -- Snake / Venomous Snake (hunter, Snake Trap)
    [19921] = true, -- Viper (hunter, Snake Trap)
    [27829] = true, -- Ebon Gargoyle (death knight, Summon Gargoyle)
}

NP.abs = math.abs
NP.min = math.min
NP.max = math.max

NP.WorldGetNumChildren = WorldFrame.GetNumChildren
NP.WorldGetChildren = WorldFrame.GetChildren
