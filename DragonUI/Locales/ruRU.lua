--[[
================================================================================
DragonUI - English Locale (Default)
================================================================================
Base locale. All keys use `true` (the key itself is the display value).

When adding new strings:
1. Add L[<your key>] = true here
2. Use L["Your String"] in your code
3. Add translations to other locale files
================================================================================
]]

local L = LibStub("AceLocale-3.0"):NewLocale("DragonUI", "ruRU")
if not L then return end

-- ============================================================================
-- CORE / GENERAL
-- ============================================================================

-- Combat lockdown messages
L["Cannot toggle editor mode during combat!"] = "Невозможно переключить режим редактора во время боя!"
L["Cannot reset positions during combat!"] = "Невозможно сбросить позиции во время боя!"
L["Cannot toggle keybind mode during combat!"] = "Невозможно переключить режим назначения клавиш во время боя!"
L["Cannot move frames during combat!"] = "Невозможно перемещать фреймы во время боя!"
L["Cannot open options in combat."] = "Невозможно открыть настройки во время боя."
L["Options panel not available. Try /reload."] = "Панель настроек недоступна. Попробуйте /reload."

-- Module availability
L["Editor mode not available."] = "Режим редактора недоступен."
L["Keybind mode not available."] = "Режим назначения клавиш недоступен."
L["Vehicle debug not available"] = "Отладка транспорта недоступна"
L["KeyBinding module not available"] = "Модуль назначения клавиш недоступен"
L["Unable to open configuration"] = "Не удалось открыть настройки"
L["Commands: /dragonui config, /dragonui edit"] = "Команды: /dragonui config, /dragonui edit"
L["Reset position: %s"] = "Сброс позиции: %s"
L["All positions reset to defaults"] = "Все позиции сброшены по умолчанию"
L["Editor mode enabled - Drag frames to reposition"] = "Режим редактора включён — перетаскивайте фреймы для перемещения"
L["Editor mode disabled - Positions saved"] = "Режим редактора выключен — позиции сохранены"
L["Minimap module restored to Blizzard defaults"] = "Модуль миникарты восстановлен до стандартных настроек Blizzard"
L["All action bar scales reset to default values"] = "Масштаб всех панелей действий сброшен по умолчанию"
L["Minimap position reset to default"] = "Позиция миникарты сброшена по умолчанию"
L["Targeting: %s"] = "Цель: %s"
L["XP: %d/%d"] = "Опыт: %d/%d"
L["GROUP %d"] = "ГРУППА %d"
L["XP: "] = "Опыт: "
L["Remaining: "] = "Осталось: "
L["Rested: "] = "Отдых: "

-- Errors
L["Error executing pending operation:"] = "Ошибка выполнения отложенной операции:"
L["Error -- Addon 'DragonUI_Options' not found or is disabled."] = "Ошибка — Аддон 'DragonUI_Options' не найден или отключён."

-- ============================================================================
-- SLASH COMMANDS / HELP
-- ============================================================================

L["Unknown command: "] = "Неизвестная команда: "
L["=== DragonUI Commands ==="] = "=== Команды DragonUI ==="
L["/dragonui or /dui - Open configuration"] = "/dragonui или /dui — Открыть настройки"
L["/dragonui config - Open configuration"] = "/dragonui config — Открыть настройки"
L["/dragonui edit - Toggle editor mode (move UI elements)"] = "/dragonui edit — Переключить режим редактора (перемещение элементов)"
L["/dragonui reset - Reset all positions to defaults"] = "/dragonui reset — Сбросить все позиции по умолчанию"
L["/dragonui reset <name> - Reset specific mover"] = "/dragonui reset <имя> — Сбросить конкретный элемент"
L["/dragonui status - Show module status"] = "/dragonui status — Показать статус модулей"
L["/dragonui kb - Toggle keybind mode"] = "/dragonui kb — Переключить режим назначения клавиш"
L["/dragonui version - Show version info"] = "/dragonui version — Показать версию"
L["/dragonui help - Show this help"] = "/dragonui help — Показать справку"
L["/rl - Reload UI"] = "/rl — Перезагрузить интерфейс"

-- ============================================================================
-- STATUS DISPLAY
-- ============================================================================

L["=== DragonUI Status ==="] = "=== Статус DragonUI ==="
L["Detected Modules:"] = "Обнаруженные модули:"
L["Loaded"] = "Загружен"
L["Not Loaded"] = "Не загружен"
L["Target Frame"] = true
L["Focus Frame"] = true
L["Party Frames"] = true
L["Cooldowns"] = true
L["Registered Movers: "] = "Зарегистрированные элементы перемещения: "
L["Editable Frames: "] = "Редактируемые фреймы: "
L["DragonUI Version: "] = "Версия DragonUI: "
L["Use /dragonui edit to enter edit mode, then right-click frames to reset."] = "Используйте /dragonui edit для входа в режим редактора, ПКМ по фрейму для сброса."

-- ============================================================================
-- EDITOR MODE
-- ============================================================================

L["Exit Edit Mode"] = "Выйти из режима редактора"
L["Reset All Positions"] = "Сбросить все позиции"
L["Are you sure you want to reset all interface elements to their default positions?"] = "Вы уверены, что хотите сбросить все элементы интерфейса в позиции по умолчанию?"
L["Yes"] = "Да"
L["No"] = "Нет"
L["UI elements have been repositioned. Reload UI to ensure all graphics display correctly?"] = "Элементы интерфейса были перемещены. Перезагрузить интерфейс для корректного отображения?"
L["Reload Now"] = "Перезагрузить"
L["Later"] = "Позже"

-- Position presets (edit mode)
L["Position Presets"] = "Пресеты позиций"
L["Position Preset"] = "Пресет позиций"
L["Save"] = "Сохранить"
L["Import"] = "Импорт"
L["Cancel"] = "Отмена"
L["Load"] = "Загрузить"
L["Delete"] = "Удалить"
L["Select All"] = "Выделить всё"
L["Click to load"] = "Нажмите для загрузки"
L["No position presets saved yet."] = "Пресеты позиций ещё не сохранены."
L["Load position preset '%s'? This will overwrite your current element positions."] = "Загрузить пресет '%s'? Текущие позиции элементов будут перезаписаны."
L["Delete position preset '%s'? This cannot be undone."] = "Удалить пресет '%s'? Это действие нельзя отменить."
L["Enter a name for the imported position preset:"] = "Введите имя для импортированного пресета:"
L["Imported Position Preset"] = "Импортированный пресет"
L["Position preset saved: "] = "Пресет позиций сохранён: "
L["Position preset loaded: "] = "Пресет позиций загружен: "
L["Position preset deleted: "] = "Пресет позиций удалён: "
L["Position preset imported: "] = "Пресет позиций импортирован: "
L["Export Position Preset"] = "Экспорт пресета позиций"
L["Import Position Preset"] = "Импорт пресета позиций"
L["Invalid position preset string."] = "Недопустимая строка пресета позиций."
L["Not a valid DragonUI position preset string."] = "Не является допустимой строкой пресета позиций DragonUI."
L["Failed to export position preset."] = "Не удалось экспортировать пресет позиций."
L["Save New Preset"] = "Сохранить новый пресет"
L["Load Preset"] = "Загрузить пресет"
L["Delete Preset"] = "Удалить пресет"
L["Export Preset"] = "Экспорт пресета"
L["Import Preset"] = "Импорт пресета"

-- ============================================================================
-- KEYBINDING MODULE
-- ============================================================================

L["LibKeyBound-1.0 not found or failed to load:"] = "LibKeyBound-1.0 не найден или не удалось загрузить:"
L["Commands:"] = "Команды:"
L["/dukb - Toggle keybinding mode"] = "/dukb — Переключить режим назначения клавиш"
L["/dukb help - Show this help"] = "/dukb help — Показать справку"
L["Module disabled."] = "Модуль отключён."
L["Keybinding mode activated. Hover over buttons and press keys to bind them."] = "Режим назначения клавиш активирован. Наведите курсор на кнопку и нажмите клавишу для привязки."
L["Keybinding mode deactivated."] = "Режим назначения клавиш деактивирован."

-- ============================================================================
-- GAME MENU
-- ============================================================================


-- ============================================================================
-- MINIMAP MODULE
-- ============================================================================

L["DragonUI: Minimap module restored to Blizzard defaults"] = "DragonUI: Модуль миникарты восстановлен до стандартных настроек Blizzard"
L["Minimap Buttons"] = "Кнопки миникарты"
L["Minimap Buttons Collector"] = "Кнопки миникарты"
L["Left-click to show or hide minimap addon buttons."] = "ЛКМ, чтобы открыть кнопки аддонов миникарты."
L["Right-click to open DragonUI settings."] = "ПКМ, чтобы открыть настройки DragonUI."

-- ============================================================================
-- EDITOR MODE LABELS (displayed on mover overlays)
-- ============================================================================

L["MainBar"] = "Основная панель"
L["RightBar"] = "Правая панель"
L["LeftBar"] = "Левая панель"
L["BottomBarLeft"] = "Нижняя левая"
L["BottomBarRight"] = "Нижняя правая"
L["XPBar"] = "Полоса опыта"
L["RepBar"] = "Полоса репутации"
L["MinimapFrame"] = "Миникарта"
L["LFGFrame"] = "Поиск подземелий"
L["PlayerFrame"] = "Игрок"
L["ManaBar"] = "Полоса маны"
L["PetFrame"] = "Питомец"
L["ToF"] = "Цель фокуса"
L["tot"] = "Цель цели"
L["ToT"] = "Цель цели"
L["fot"] = "Фокус цели"
L["PartyFrames"] = "Группа"
L["TargetFrame"] = "Цель"
L["FocusFrame"] = "Фокус"
L["TargetCastbar"] = "Полоса заклинаний цели"
L["FocusCastbar"] = "Полоса заклинаний фокуса"
L["BagsBar"] = "Сумки"
L["MicroMenu"] = "Микроменю"
L["VehicleExitOverlay"] = "Выход из транспорта"
L["StanceOverlay"] = "Панель стоек"
L["petbar"] = "Панель питомца"
L["ExtraBar1"] = "Дополнительная панель"
L["boss"] = "Фреймы боссов"
L["Boss Frames"] = "Фреймы боссов"
L["Boss1Frame"] = "Фреймы боссов"
L["Boss2Frame"] = "Фреймы боссов"
L["Boss3Frame"] = "Фреймы боссов"
L["Boss4Frame"] = "Фреймы боссов"
L["TotemBarOverlay"] = "Панель тотемов"
L["PlayerCastbar"] = "Полоса заклинаний"
L["TooltipWidget"] = "Подсказка"
L["Buff"] = "Баф"
L["Debuffs"] = "Дебаф"
L["WeaponEnchants"] = "Зачарования оружия"
L["Loot Roll"] = "Розыгрыш добычи"
L["Quest Tracker"] = "Трекер заданий"

-- Mover tooltip strings
L["Drag to move"] = "Перетащите для перемещения"
L["Animated minimap border effects for DragonUI."] = "Анимированные эффекты рамки миникарты для DragonUI."
L["Click to reset"] = "Клик для сброса"
L["Right-click to reset"] = "ПКМ для сброса"
L["Status Tooltip:"] = "Подсказка статуса:"
L["Top"] = "Сверху"
L["Bottom"] = "Снизу"
L["Left"] = "Слева"
L["Right"] = "Справа"
L["Error Messages"] = "Сообщения об ошибках"
L["ErrorMessages"] = "Сообщения об ошибках"

-- Editor mode system messages
L["All editable frames shown for editing"] = "Все редактируемые фреймы показаны для редактирования"
L["All editable frames hidden, positions saved"] = "Все редактируемые фреймы скрыты, позиции сохранены"

-- ============================================================================
-- COMPATIBILITY MODULE
-- ============================================================================

-- Conflict warning popup
L["DragonUI Conflict Warning"] = "DragonUI — Предупреждение о конфликте"
L["The addon |cFFFFFF00%s|r conflicts with DragonUI."] = "Аддон |cFFFFFF00%s|r конфликтует с DragonUI."
L["Reason:"] = "Причина:"
L["Disable the conflicting addon now?"] = "Отключить конфликтующий аддон сейчас?"
L["Keep Both"] = "Оставить оба"
L["DragonUI - D3D9Ex Warning"] = "DragonUI — Предупреждение о D3D9Ex"
L["DragonUI detected that your client is using D3D9Ex."] = "DragonUI обнаружил, что ваш клиент использует D3D9Ex."
L["DragonUI's action bar system is not compatible with D3D9Ex."] = "Система панелей действий DragonUI несовместима с D3D9Ex."
L["Some DragonUI action bar textures will be missing while this mode is active."] = "Пока этот режим активен, часть текстур панелей действий DragonUI будет отсутствовать."
L["If you want to disable this mode, open WTF\\Config.wtf."] = "Если вы хотите отключить этот режим, откройте WTF\\Config.wtf."
L["Delete this line:"] = "Удалите эту строку:"
L["Or replace it with:"] = "Или замените её на:"
L["Hide Gryphons"] = "Скрыть грифонов"
L["Understood"] = "Понятно"
L["DragonUI - UnitFrameLayers Detected"] = "DragonUI — Обнаружен UnitFrameLayers"
L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] = "DragonUI уже включает функциональность Unit Frame Layers (предсказание исцеления, щиты поглощения и анимация потери здоровья)."
L["Choose how to resolve this overlap:"] = "Выберите, как разрешить это пересечение:"
L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] = "Использовать DragonUI: отключить внешний UnitFrameLayers и включить слои DragonUI."
L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."] = "Отключить оба: отключить внешний UnitFrameLayers и оставить слои DragonUI выключенными."
L["Use DragonUI"] = "Использовать DragonUI"
L["Disable Both"] = "Отключить оба"
L["Use DragonUI Unit Frame Layers"] = "Использовать слои фреймов DragonUI"
L["Disable both Unit Frame Layers"] = "Отключить оба варианта слоёв фреймов"
L["DragonUI - Party Frame Issue"] = true
L["You joined a party while in combat. Due to CompactRaidFrame taint issues, party frames may not display correctly."] = true
L["Reload the UI to fix party frame display?"] = true

-- Conflict reasons
L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = "Конфликтует с пользовательскими текстурами фреймов и системой полос ресурсов DragonUI."
L["Known taint issues when manipulating party frames during combat. DragonUI provides automatic fixes."] = "Известные проблемы с taint при изменении фреймов группы в бою. DragonUI применяет автоматические исправления."
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = "Сбрасывает маску и текстуры миникарты. DragonUI автоматически восстанавливает свои текстуры."
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = "SexyMap изменяет границы, форму и текст зоны миникарты, что конфликтует с модулем миникарты DragonUI."
L["Reads native nameplate alpha to identify the target's plate; conflicts with DragonUI's default anti-dim behavior."] = "Использует нативную прозрачность плашки для определения плашки цели; конфликтует со стандартным поведением DragonUI по устранению затемнения."
L["Parents its cooldown icons to the native health bar; conflicts with DragonUI's default health-bar hiding."] = "Привязывает значки кулдаунов к нативной полосе здоровья; конфликтует со стандартным скрытием этой полосы в DragonUI."

-- Nameplate addon compatibility popup
L["Detected |cFFFFFF00%s|r. Enable Nameplate Addon Compatibility so it works correctly?"] = "Обнаружен |cFFFFFF00%s|r. Включить совместимость с аддонами плашек, чтобы он работал корректно?"
L["Detected |cFFFFFF00%s|r. Enable Nameplate Health Bar Compatibility so it works correctly?"] = "Обнаружен |cFFFFFF00%s|r. Включить совместимость полосы здоровья плашек, чтобы он работал корректно?"
L["Enable"] = "Включить"

-- SexyMap compatibility popup
L["DragonUI - SexyMap Detected"] = "DragonUI — Обнаружен SexyMap"
L["Which minimap do you want to use?"] = "Какую миникарту вы хотите использовать?"
L["SexyMap"] = "SexyMap"
L["DragonUI"] = "DragonUI"
L["Hybrid"] = "Гибрид"
L["Recommended"] = "Рекомендуется"

-- SexyMap options panel
L["SexyMap Compatibility"] = "Совместимость с SexyMap"
L["Minimap Mode"] = "Режим миникарты"
L["Choose how DragonUI and SexyMap share the minimap."] = "Выберите, как DragonUI и SexyMap делят миникарту."
L["Requires UI reload to apply."] = "Требуется перезагрузка интерфейса для применения."
L["Uses SexyMap for the minimap."] = "Использовать SexyMap для миникарты."
L["Uses DragonUI for the minimap."] = "Использовать DragonUI для миникарты."
L["SexyMap visuals with DragonUI editor and positioning."] = "Визуал SexyMap с редактором и позиционированием DragonUI."
L["Minimap mode changed. Reload UI to apply?"] = "Режим миникарты изменён. Перезагрузить интерфейс для применения?"

-- SexyMap slash commands
L["SexyMap compatibility mode has been reset. Reload UI to choose again."] = "Режим совместимости с SexyMap сброшен. Перезагрузите интерфейс для повторного выбора."
L["Current SexyMap mode: |cFFFFFF00%s|r"] = "Текущий режим SexyMap: |cFFFFFF00%s|r"
L["No SexyMap mode selected (SexyMap not detected or not yet chosen)."] = "Режим SexyMap не выбран (SexyMap не обнаружен или ещё не выбран)."
L["Show current SexyMap compatibility mode"] = "Показать текущий режим совместимости с SexyMap"
L["Reset SexyMap mode choice (re-prompts on reload)"] = "Сбросить выбор режима SexyMap (повторный запрос при перезагрузке)"
L["Loaded addons:"] = "Загруженные аддоны:"

-- ============================================================================
-- STATIC POPUPS (shared between modules)
-- ============================================================================

L["Changing this setting requires a UI reload to apply correctly."] = "Для применения этой настройки требуется перезагрузка интерфейса."
L["Reload UI"] = "Перезагрузить"
L["Not Now"] = "Не сейчас"
L["Disable"] = "Отключить"
L["Ignore"] = "Игнорировать"
L["Skip"] = "Пропустить"
L["The Blizzard option |cFFFFFF00Party/Arena Background|r is enabled. This conflicts with DragonUI's party frames."] = "Опция Blizzard |cFFFFFF00Фон группы/арены|r включена. Это конфликтует с фреймами группы DragonUI."
L["Disable it now?"] = "Отключить сейчас?"
L["Some interface settings are not configured optimally for DragonUI."] = "Некоторые настройки интерфейса настроены не оптимально для DragonUI."
L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] = "Сюда входят настройки, конфликтующие с DragonUI, а также рекомендуемые настройки для лучшего визуального восприятия."
L["Affected settings:"] = "Затронутые настройки:"
L["Some interface settings are not configured optimally for DragonUI. Do you want to fix them?"] = "Некоторые настройки интерфейса настроены не оптимально для DragonUI. Исправить их?"
L["Do you want to fix them now?"] = "Исправить их сейчас?"
L["Party/Arena Background"] = "Фон группы/арены"
L["Default Status Text"] = "Стандартный текст статуса"
L["Conflict"] = "Конфликт"
L["Recommended"] = "Рекомендуется"

-- Bag Sort
L["Sort Bags"] = "Сортировать сумки"
L["Sort Bank"] = "Сортировать банк"
L["Sort Items"] = "Сортировать предметы"
L["Click to sort items by type, rarity, and name."] = "Нажмите для сортировки предметов по типу, редкости и названию."
L["Clear Locked Slots"] = "Очистить заблокированные ячейки"
L["Click to clear all locked bag slots."] = "Нажмите для очистки всех заблокированных ячеек сумок."
L["Alt+LeftClick any bag slot (item or empty) to lock or unlock it."] = "Alt+ЛКМ по любой ячейке сумки (с предметом или пустой) для блокировки/разблокировки."
L["Click the lock-clear button to remove all locked slots."] = "Нажмите кнопку очистки блокировок для снятия всех блокировок."
L["Hover an item or slot, then type /sortlock."] = "Наведите курсор на предмет или ячейку, затем введите /sortlock."
L["Slot locked (bag %d, slot %d)."] = "Ячейка заблокирована (сумка %d, ячейка %d)."
L["Slot unlocked (bag %d, slot %d)."] = "Ячейка разблокирована (сумка %d, ячейка %d)."
L["Could not clear locks (config not ready)."] = "Не удалось очистить блокировки (конфигурация не готова)."
L["Cleared all sort-locked slots."] = "Все заблокированные ячейки очищены."

-- Sell Scrap
L["Sell Scrap"] = "Продать хлам"
L["Open a merchant window first to sell scrap items."] = "Сначала откройте окно торговца, чтобы продать хлам."

-- Guild Bank Sort
L["You must be at the guild bank."] = "Вы должны находиться в гильдейском банке."
L["Could not determine the current guild bank tab."] = "Не удалось определить текущую вкладку гильдейского банка."
L["You need full deposit and withdraw access to this tab to sort it."] = "Вам нужен полный доступ на внесение и снятие для этой вкладки, чтобы её отсортировать."
L["This guild bank tab is already sorted!"] = "Эта вкладка гильдейского банка уже отсортирована!"
L["Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."] = "Отсортировать эту вкладку гильдейского банка? В зависимости от сервера это может быть записано в журнал и засчитано в общий лимит снятия вашей гильдии, как и при ручном перемещении предметов."
L["Sort"] = "Сортировать"
L["Click to sort items in the currently open guild bank tab."] = "Нажмите, чтобы отсортировать предметы в текущей открытой вкладке гильдейского банка."
L["Never moves items between tabs."] = "Никогда не перемещает предметы между вкладками."
L["Sort Guild Bank Tab"] = "Сортировать вкладку гильдейского банка"

-- Micromenu Latency
L["Network"] = "Сеть"
L["Latency"] = "Задержка"

-- ============================================================================
-- STABILIZATION PATCH STRINGS
-- ============================================================================

L["/dragonui debug on|off|status - Toggle diagnostic logging"] = "/dragonui debug on|off|status — Переключить диагностическое логирование"
L["Usage: /dragonui debug on|off|status"] = "Использование: /dragonui debug on|off|status"
L["Enable debug mode first with /dragonui debug on"] = "Сначала включите режим отладки: /dragonui debug on"
L["Debug mode is %s"] = "Режим отладки: %s"
L["Debug mode enabled"] = "Режим отладки включён"
L["Debug mode disabled"] = "Режим отладки выключен"
L["enabled"] = true
L["disabled"] = true
L["Enabled"] = "Включён"
L["Disabled"] = "Выключен"
L["Legacy refresh failed for"] = true
L["RegisterMover: name and parent are required"] = true
L["Bonus Action Button %d"] = true
L["Stance Button %d"] = true
L["Pet Action Button %d"] = true
L["Multicast Button %d"] = true
L["Totem Call Button"] = true
L["Totem Recall Button"] = true
L["Bottom Left Button"] = true
L["Bottom Right Button"] = true
L["Right Button"] = true
L["Left Button"] = true
L["Totem Bar"] = true
L["Test Pet"] = true
L["=== TargetFrame children (depth 3) ==="] = true
L["=== FocusFrame children (depth 3) ==="] = true
L["BG texture not found"] = true
L["BG tinted RED"] = true
L["BG tinted GREEN"] = true
L["BG color reset"] = true
L["=== BANK SCAN DEBUG ==="] = true
L["=== BANK QUALITY DEBUG ==="] = true
L["Module enabled:"] = true
L["BankFrame exists:"] = true
L["BankFrame shown:"] = true
L["Usage: /dui shadowcolor red|green|reset|info"] = true
L["Usage: /dui shadowcrop <bottom_px> [right_px]"] = true
L["  e.g. /dui shadowcrop 90 - show top 90 of 128 px height"] = true
L["  e.g. /dui shadowcrop 90 200 - crop both bottom and right"] = true
L["  /dui shadowcrop reset - restore full texture"] = true
L["BG reset to 256x128 full texture"] = true
L["Crop applied: showing %dx%d of 256x128 (texcoord 0-%.3f, 0-%.3f)"] = true
L["Invalid values. Height 1-128, Width 1-256"] = true
L["=== TargetFrame elements (use /dui shadowtest N to toggle) ==="] = true
L["Total elements: %d"] = true
L["HIDDEN: %d. %s [%s]"] = true
L["SHOWN: %d. %s [%s]"] = true
L["Invalid element number. Use /dui shadowtest to list."] = true
L["DragonUI Compatibility:"] = true
L["Registered Modules:"] = "Зарегистрированные модули:"
L["No modules registered in ModuleRegistry"] = "В реестре модулей нет зарегистрированных модулей"
L["load-once"] = "однократная загрузка"
L["%s will disable after /reload because its secure hooks cannot be removed safely."] = "%s будет отключён после /reload, т.к. его защищённые хуки нельзя безопасно удалить."
L["%s uses permanent secure hooks and will fully disable after /reload."] = "%s использует постоянные защищённые хуки и полностью отключится после /reload."
L["%s remains active until /reload because its secure hooks cannot be removed safely."] = "%s остаётся активным до /reload, т.к. его защищённые хуки нельзя безопасно удалить."
L["Cooldown Text"] = "Текст перезарядки"
L["Cooldown text on action buttons"] = "Текст перезарядки на кнопках действий"
L["Cast Bar"] = "Полоса заклинаний"
L["Custom player, target, and focus cast bars"] = "Пользовательские полосы заклинаний игрока, цели и фокуса"
L["Multicast"] = "Мультикаст"
L["Shaman totem bar positioning and styling"] = "Позиционирование и стилизация панели тотемов шамана"
L["Player Frame"] = "Фрейм игрока"
L["Dragonflight-styled boss target frames"] = "Фреймы боссов в стиле Dragonflight"
L["Dragonflight-styled player unit frame"] = "Фрейм игрока в стиле Dragonflight"
L["ModuleRegistry:Register requires name and moduleTable"] = "ModuleRegistry:Register требует name и moduleTable"
L["ModuleRegistry: Module already registered -"] = "ModuleRegistry: Модуль уже зарегистрирован —"
L["ModuleRegistry: Registered module -"] = "ModuleRegistry: Модуль зарегистрирован —"
L["order:"] = "порядок:"
L["ModuleRegistry: Refresh failed for"] = "ModuleRegistry: Ошибка обновления для"
L["ModuleRegistry: Unknown module -"] = "ModuleRegistry: Неизвестный модуль —"
L["ModuleRegistry: Enabled -"] = "ModuleRegistry: Включён —"
L["ModuleRegistry: Disabled -"] = "ModuleRegistry: Выключен —"
L["CombatQueue:Add requires id and func"] = "CombatQueue:Add требует id и func"
L["CombatQueue: Registered PLAYER_REGEN_ENABLED"] = "CombatQueue: Зарегистрировано PLAYER_REGEN_ENABLED"
L["CombatQueue: Queued operation -"] = "CombatQueue: Операция в очереди —"
L["CombatQueue: Removed operation -"] = "CombatQueue: Операция удалена —"
L["CombatQueue: Processing"] = "CombatQueue: Обработка"
L["queued operations"] = "операций в очереди"
L["CombatQueue: Failed to execute"] = "CombatQueue: Ошибка выполнения"
L["CombatQueue: Executed -"] = "CombatQueue: Выполнено —"
L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"] = "CombatQueue: Снята регистрация PLAYER_REGEN_ENABLED"
L["CombatQueue: Immediate execution failed -"] = "CombatQueue: Ошибка немедленного выполнения —"

-- ============================================================================
-- RELEASE PREP STRINGS
-- ============================================================================

L["Buttons"] = "Кнопки"
L["Action button styling and enhancements"] = "Стилизация и улучшения кнопок действий"
L["Dark Mode"] = "Тёмный режим"
L["Darken UI borders and chrome"] = "Затемнение рамок и элементов интерфейса"
L["Item Quality"] = "Качество предметов"
L["Color item borders by quality in bags, character panel, bank, and merchant"] = "Окрашивание рамок предметов по качеству в сумках, окне персонажа, банке и у торговца"
L["Key Binding"] = "Назначение клавиш"
L["LibKeyBound integration for intuitive keybinding"] = "Интеграция LibKeyBound для удобного назначения клавиш"
L["Buff Frame"] = "Фрейм эффектов"
L["Custom buff frame styling, positioning and toggle button"] = "Стилизация, позиционирование и кнопка переключения фрейма эффектов"
L["Chat Mods"] = "Улучшения чата"
L["Chat enhancements: hide buttons, editbox position, URL copy, chat copy, link hover, tell target"] = "Улучшения чата: скрытие кнопок, позиция строки ввода, копирование URL, копирование чата, ховер ссылок, шёпот цели"
L["Bag Sort"] = "Сортировка сумок"
L["Sort bags and bank items with buttons"] = "Сортировка предметов в сумках и банке кнопками"
L["Bag Skin"] = "Оформление сумок"
L["Retail-style skin for Blizzard bag windows"] = "Оформление окон сумок Blizzard в стиле Retail"
L["Bagster"] = "Bagster"
L["All-in-one bag replacement with filtering and search"] = "Универсальная замена сумок с фильтрацией и поиском"
L["Stance Bar"] = "Панель стоек"
L["Vehicle"] = "Транспорт"
L["Vehicle interface enhancements"] = "Улучшения интерфейса транспорта"
L["Pet Bar"] = "Панель питомца"
L["Extra Bar"] = "Дополнительная панель"
L["A standalone action bar, independent of any class bonus bar"] = "Независимая панель действий, не связанная с дополнительной панелью класса"
L["Drag a spell, item or macro here."] = "Перетащите сюда заклинание, предмет или макрос."
L["Micro Menu"] = "Микроменю"
L["Main Bars"] = "Основные панели"
L["Main action bars, status bars, scaling and positioning"] = "Основные панели действий, полосы статуса, масштабирование и позиционирование"
L["Hide Blizzard"] = "Скрыть Blizzard"
L["Hide default Blizzard UI elements"] = "Скрыть стандартные элементы интерфейса Blizzard"
L["Minimap"] = "Миникарта"
L["Custom minimap styling, positioning, tracking icons and calendar"] = "Стилизация миникарты, позиционирование, значки отслеживания и календарь"
L["Quest tracker positioning and styling"] = "Позиционирование и стилизация трекера заданий"
L["Tooltip"] = "Подсказка"
L["Enhanced tooltip styling with class colors and health bars"] = "Улучшенные подсказки с цветами классов и полосами здоровья"
L["Nameplates"] = "Индикаторы"
L["Apply DragonUI nameplate styling."] = "Применяет стиль DragonUI к индикаторам."
L["Unit Frame Layers"] = "Слои фреймов"
L["Heal prediction, absorb shields, and animated health loss on unit frames"] = "Предсказание исцеления, щиты поглощения и анимация потери здоровья на фреймах"
L["Stance/shapeshift bar positioning and styling"] = "Позиционирование и стилизация панели стоек/форм"
L["Pet action bar positioning and styling"] = "Позиционирование и стилизация панели действий питомца"
L["Micro menu and bags system styling and positioning"] = "Стилизация и позиционирование микроменю и системы сумок"
L["|cff00ff00Left-Click|r to show this bag's items"] = "|cff00ff00ЛКМ|r — показать предметы этой сумки"
L["|cff00ff00Left-Click|r to hide this bag's items"] = "|cff00ff00ЛКМ|r — скрыть предметы этой сумки"
L["|cff00ff00Drag|r to move this bag"] = "|cff00ff00Перетащите|r, чтобы переместить эту сумку"
L["Sort complete."] = "Сортировка завершена."
L["Sort already in progress."] = "Сортировка уже выполняется."
L["Bags already sorted!"] = "Сумки уже отсортированы!"
L["You must be at the bank."] = "Вы должны находиться у банка."
L["Bank already sorted!"] = "Банк уже отсортирован!"
L["Reputation: "] = "Репутация: "
L["Error in SafeCall:"] = "Ошибка в SafeCall:"

L["Copy Text"] = "Копировать текст"


L["Version Check"] = "Проверка версий"
L["Broadcast and detect addon version updates across group members"] = "Обнаруживает обновления аддона среди участников группы, отправляя и получая версию"

-- Quest nameplate icons wizard (Questie coexistence)
L["Quest Icons on Nameplates"] = "Значки заданий на табличках"
L["Which quest icons do you want on your nameplates?"] = "Какие значки заданий показывать на табличках?"
L["Kill"] = "Убийство"
L["Loot"] = "Добыча"
L['Pointer mode (just "!")'] = 'Режим указателя (только «!»)'
L["Use Questie"] = "Использовать Questie"
L["Applying quest icon settings needs a UI reload."] = "Для применения настроек значков заданий нужна перезагрузка интерфейса."
L["Reload"] = "Перезагрузить"
