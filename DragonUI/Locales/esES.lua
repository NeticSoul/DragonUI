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

local L = LibStub("AceLocale-3.0"):NewLocale("DragonUI", "esES")
if not L then return end

-- ============================================================================
-- CORE / GENERAL
-- ============================================================================

-- Combat lockdown messages
L["Cannot toggle editor mode during combat!"] = "¡No se puede cambiar el modo editor durante combate!"
L["Cannot reset positions during combat!"] = "¡No se pueden restablecer las posiciones durante combate!"
L["Cannot toggle keybind mode during combat!"] = "¡No se puede cambiar el modo de atajos durante combate!"
L["Cannot move frames during combat!"] = "¡No se pueden mover marcos durante combate!"
L["Cannot open options in combat."] = "No se pueden abrir las opciones en combate."
L["Options panel not available. Try /reload."] = "Panel de opciones no disponible. Prueba /reload."

-- Module availability
L["Editor mode not available."] = "Modo editor no disponible."
L["Keybind mode not available."] = "Modo de atajos no disponible."
L["Vehicle debug not available"] = "Depuración de vehículo no disponible"
L["KeyBinding module not available"] = "Módulo de atajos de teclado no disponible"
L["Unable to open configuration"] = "No se pudo abrir la configuración"
L["Commands: /dragonui config, /dragonui edit"] = "Comandos: /dragonui config, /dragonui edit"
L["Reset position: %s"] = "Posición restablecida: %s"
L["All positions reset to defaults"] = "Todas las posiciones restablecidas a valores predeterminados"
L["Editor mode enabled - Drag frames to reposition"] = "Modo editor activado - Arrastra los marcos para reposicionar"
L["Editor mode disabled - Positions saved"] = "Modo editor desactivado - Posiciones guardadas"
L["Minimap module restored to Blizzard defaults"] = "Módulo de minimapa restaurado a valores predeterminados de Blizzard"
L["All action bar scales reset to default values"] = "Todas las escalas de barras de acción restablecidas a valores predeterminados"
L["Minimap position reset to default"] = "Posición del minimapa restablecida a valores predeterminados"
L["Targeting: %s"] = "Apuntando a: %s"
L["XP: %d/%d"] = "XP: %d/%d"
L["GROUP %d"] = "GRUPO %d"
L["XP: "] = "XP: "
L["Remaining: "] = "Restante: "
L["Rested: "] = "Descanso: "

-- Errors
L["Error executing pending operation:"] = "Error al ejecutar operación pendiente:"
L["Error -- Addon 'DragonUI_Options' not found or is disabled."] = "Error -- El addon 'DragonUI_Options' no se encontró o está desactivado."

-- ============================================================================
-- SLASH COMMANDS / HELP
-- ============================================================================

L["Unknown command: "] = "Comando desconocido: "
L["=== DragonUI Commands ==="] = "=== Comandos de DragonUI ==="
L["/dragonui or /dui - Open configuration"] = "/dragonui o /dui - Abrir configuración"
L["/dragonui config - Open configuration"] = "/dragonui config - Abrir configuración"
L["/dragonui edit - Toggle editor mode (move UI elements)"] = "/dragonui edit - Cambiar modo editor (mover elementos de UI)"
L["/dragonui reset - Reset all positions to defaults"] = "/dragonui reset - Restablecer todas las posiciones"
L["/dragonui reset <name> - Reset specific mover"] = "/dragonui reset <nombre> - Restablecer posición específica"
L["/dragonui status - Show module status"] = "/dragonui status - Mostrar estado de módulos"
L["/dragonui kb - Toggle keybind mode"] = "/dragonui kb - Cambiar modo de atajos"
L["/dragonui version - Show version info"] = "/dragonui version - Mostrar versión"
L["/dragonui help - Show this help"] = "/dragonui help - Mostrar esta ayuda"
L["/rl - Reload UI"] = "/rl - Recargar interfaz"

-- ============================================================================
-- STATUS DISPLAY
-- ============================================================================

L["=== DragonUI Status ==="] = "=== Estado de DragonUI ==="
L["Detected Modules:"] = "Módulos detectados:"
L["Loaded"] = "Cargado"
L["Not Loaded"] = "No cargado"
L["Target Frame"] = true
L["Focus Frame"] = true
L["Party Frames"] = true
L["Cooldowns"] = true
L["Registered Movers: "] = "Movedores registrados: "
L["Editable Frames: "] = "Marcos editables: "
L["DragonUI Version: "] = "Versión de DragonUI: "
L["Use /dragonui edit to enter edit mode, then right-click frames to reset."] = "Usa /dragonui edit para entrar en modo edición, luego haz clic derecho en marcos para restablecer."

-- ============================================================================
-- EDITOR MODE
-- ============================================================================

L["Exit Edit Mode"] = "Salir Editor"
L["Reset All Positions"] = "Restablecer Posiciones"
L["Are you sure you want to reset all interface elements to their default positions?"] = "¿Restablecer todos los elementos a su posición predeterminada?"
L["Yes"] = "Sí"
L["No"] = "No"
L["UI elements have been repositioned. Reload UI to ensure all graphics display correctly?"] = "Los elementos de la interfaz han sido reposicionados. ¿Recargar la interfaz para que se muestren correctamente?"
L["Reload Now"] = "Recargar Ahora"
L["Later"] = "Más Tarde"

-- Position presets (edit mode)
L["Position Presets"] = "Preajustes de Posición"
L["Position Preset"] = "Preajuste de Posición"
L["Save"] = "Guardar"
L["Import"] = "Importar"
L["Cancel"] = "Cancelar"
L["Load"] = "Cargar"
L["Delete"] = "Eliminar"
L["Select All"] = "Seleccionar Todo"
L["Click to load"] = "Clic para cargar"
L["No position presets saved yet."] = "Aún no hay preajustes de posición guardados."
L["Load position preset '%s'? This will overwrite your current element positions."] = "¿Cargar preajuste '%s'? Se sobrescribirán las posiciones actuales de los elementos."
L["Delete position preset '%s'? This cannot be undone."] = "¿Eliminar preajuste '%s'? Esta acción no se puede deshacer."
L["Enter a name for the imported position preset:"] = "Introduce un nombre para el preajuste importado:"
L["Imported Position Preset"] = "Preajuste Importado"
L["Position preset saved: "] = "Preajuste de posición guardado: "
L["Position preset loaded: "] = "Preajuste de posición cargado: "
L["Position preset deleted: "] = "Preajuste de posición eliminado: "
L["Position preset imported: "] = "Preajuste de posición importado: "
L["Export Position Preset"] = "Exportar Preajuste de Posición"
L["Import Position Preset"] = "Importar Preajuste de Posición"
L["Invalid position preset string."] = "Cadena de preajuste de posición no válida."
L["Not a valid DragonUI position preset string."] = "No es una cadena de preajuste de posición DragonUI válida."
L["Failed to export position preset."] = "No se pudo exportar el preajuste de posición."
L["Save New Preset"] = "Guardar Nuevo Preajuste"
L["Load Preset"] = "Cargar Preajuste"
L["Delete Preset"] = "Eliminar Preajuste"
L["Export Preset"] = "Exportar Preajuste"
L["Import Preset"] = "Importar Preajuste"

-- ============================================================================
-- KEYBINDING MODULE
-- ============================================================================

L["LibKeyBound-1.0 not found or failed to load:"] = "LibKeyBound-1.0 no encontrado o error al cargar:"
L["Commands:"] = "Comandos:"
L["/dukb - Toggle keybinding mode"] = "/dukb - Cambiar modo de atajos"
L["/dukb help - Show this help"] = "/dukb help - Mostrar esta ayuda"
L["Module disabled."] = "Módulo desactivado."
L["Keybinding mode activated. Hover over buttons and press keys to bind them."] = "Modo de atajos activado. Pasa el ratón sobre los botones y pulsa teclas para asignarlas."
L["Keybinding mode deactivated."] = "Modo de atajos desactivado."

-- ============================================================================
-- GAME MENU
-- ============================================================================


-- ============================================================================
-- MINIMAP MODULE
-- ============================================================================

L["DragonUI: Minimap module restored to Blizzard defaults"] = "DragonUI: Módulo de minimapa restaurado a los valores de Blizzard"
L["Minimap Buttons"] = "Botones del minimapa"
L["Minimap Buttons Collector"] = "Botones del minimapa"
L["Left-click to show or hide minimap addon buttons."] = "Clic izquierdo para abrir los botones de addons del minimapa."
L["Right-click to open DragonUI settings."] = "Clic derecho para abrir la configuración de DragonUI."

-- ============================================================================
-- EDITOR MODE LABELS (displayed on mover overlays)
-- ============================================================================

L["MainBar"] = "Barra Princ."
L["RightBar"] = "Barra Der."
L["LeftBar"] = "Barra Izq."
L["BottomBarLeft"] = "Barra Inf. Izq."
L["BottomBarRight"] = "Barra Inf. Der."
L["XPBar"] = "Barra XP"
L["RepBar"] = "Barra Rep."
L["MinimapFrame"] = "Minimapa"
L["LFGFrame"] = "Ojo de Mazmorra"
L["PlayerFrame"] = "Jugador"
L["ManaBar"] = "Barra Maná"
L["PetFrame"] = "Mascota"
L["ToF"] = "OdF"
L["tot"] = "OdO"
L["ToT"] = "OdO"
L["fot"] = "OdF"
L["PartyFrames"] = "Grupo"
L["TargetFrame"] = "Objetivo"
L["FocusFrame"] = "Foco"
L["TargetCastbar"] = "Barra de lanzamiento de Objetivo"
L["FocusCastbar"] = "Barra de lanzamiento de Foco"
L["BagsBar"] = "Bolsas"
L["MicroMenu"] = "Micromenú"
L["VehicleExitOverlay"] = "Salir Vehículo"
L["StanceOverlay"] = "Posturas"
L["petbar"] = "Barra Mascota"
L["boss"] = "Marcos de Jefe"
L["Boss Frames"] = "Marcos de Jefe"
L["Boss1Frame"] = "Marcos de Jefe"
L["Boss2Frame"] = "Marcos de Jefe"
L["Boss3Frame"] = "Marcos de Jefe"
L["Boss4Frame"] = "Marcos de Jefe"
L["TotemBarOverlay"] = "Tótems"
L["PlayerCastbar"] = "Barra Hechizos"
L["TooltipWidget"] = "Tooltip"
L["Buff"] = "Beneficio"
L["Debuffs"] = "Perjuicio"
L["WeaponEnchants"] = "Encantamientos"
L["Loot Roll"] = "Botín"
L["Quest Tracker"] = "Misiones"

-- Mover tooltip strings
L["Drag to move"] = "Arrastra para mover"
L["Animated minimap border effects for DragonUI."] = "Efectos animados de borde de minimapa para DragonUI."
L["Right-click to reset"] = "Clic der. para reiniciar"
L["Click to reset"] = "Clic para reiniciar"
L["Status Tooltip:"] = "Tooltip de estado:"
L["Top"] = "Arriba"
L["Bottom"] = "Abajo"
L["Left"] = "Izquierda"
L["Right"] = "Derecha"
L["Error Messages"] = "Mensajes de error"
L["ErrorMessages"] = "Mensajes de error"

-- Editor mode system messages
L["All editable frames shown for editing"] = "Marcos editables mostrados"
L["All editable frames hidden, positions saved"] = "Marcos ocultados, posiciones guardadas"

-- ============================================================================
-- COMPATIBILITY MODULE
-- ============================================================================

-- Conflict warning popup
L["DragonUI Conflict Warning"] = "Advertencia de Conflicto de DragonUI"
L["The addon |cFFFFFF00%s|r conflicts with DragonUI."] = "El addon |cFFFFFF00%s|r entra en conflicto con DragonUI."
L["Reason:"] = "Razón:"
L["Disable the conflicting addon now?"] = "¿Desactivar el addon conflictivo ahora?"
L["Keep Both"] = "Mantener Ambos"
L["DragonUI - D3D9Ex Warning"] = "DragonUI - Aviso de D3D9Ex"
L["DragonUI detected that your client is using D3D9Ex."] = "DragonUI ha detectado que tu cliente está usando D3D9Ex."
L["DragonUI's action bar system is not compatible with D3D9Ex."] = "El sistema de barras de acción de DragonUI no es compatible con D3D9Ex."
L["Some DragonUI action bar textures will be missing while this mode is active."] = "Faltarán algunas texturas de las barras de acción de DragonUI mientras este modo esté activo."
L["If you want to disable this mode, open WTF\\Config.wtf."] = "Si quieres desactivar este modo, abre WTF\\Config.wtf."
L["Delete this line:"] = "Borra esta línea:"
L["Or replace it with:"] = "O cámbiala por esta otra:"
L["Hide Gryphons"] = "Esconder grifos"
L["Understood"] = "Entendido"
L["DragonUI - UnitFrameLayers Detected"] = "DragonUI - UnitFrameLayers Detectado"
L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] = "DragonUI ya incluye la funcionalidad de Unit Frame Layers (predicción de curación, escudos de absorción y pérdida de vida animada)."
L["Choose how to resolve this overlap:"] = "Elige cómo resolver esta superposición:"
L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] = "Usar DragonUI: desactiva UnitFrameLayers externo y activa las capas de DragonUI."
L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."] = "Desactivar ambos: desactiva UnitFrameLayers externo y mantiene desactivadas las capas de DragonUI."
L["Use DragonUI"] = "Usar DragonUI"
L["Disable Both"] = "Desactivar ambos"
L["Use DragonUI Unit Frame Layers"] = "Usar Unit Frame Layers de DragonUI"
L["Disable both Unit Frame Layers"] = "Desactivar ambos Unit Frame Layers"
L["DragonUI - Party Frame Issue"] = true
L["You joined a party while in combat. Due to CompactRaidFrame taint issues, party frames may not display correctly."] = true
L["Reload the UI to fix party frame display?"] = true

-- Conflict reasons
L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = "Entra en conflicto con las texturas personalizadas de marcos de unidad y el sistema de barra de poder de DragonUI."
L["Known taint issues when manipulating party frames during combat. DragonUI provides automatic fixes."] = "Problemas conocidos de contaminación al manipular marcos de grupo en combate. DragonUI proporciona correcciones automáticas."
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = "Restablece la máscara del minimapa y las texturas de puntos. DragonUI vuelve a aplicar sus texturas personalizadas automáticamente."
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = "SexyMap modifica los bordes del minimapa, la forma y el texto de zona, lo cual entra en conflicto con el módulo de minimapa de DragonUI."

-- SexyMap compatibility popup
L["DragonUI - SexyMap Detected"] = "DragonUI - SexyMap Detectado"
L["Which minimap do you want to use?"] = "¿Qué minimapa quieres usar?"
L["SexyMap"] = "SexyMap"
L["DragonUI"] = "DragonUI"
L["Hybrid"] = "Híbrido"
L["Recommended"] = "Recomendado"

-- SexyMap options panel
L["SexyMap Compatibility"] = "Compatibilidad SexyMap"
L["Minimap Mode"] = "Modo de Minimapa"
L["Choose how DragonUI and SexyMap share the minimap."] = "Elige cómo comparten el minimapa DragonUI y SexyMap."
L["Requires UI reload to apply."] = "Requiere recargar la interfaz para aplicar."
L["Uses SexyMap for the minimap."] = "Usa SexyMap para el minimapa."
L["Uses DragonUI for the minimap."] = "Usa DragonUI para el minimapa."
L["SexyMap visuals with DragonUI editor and positioning."] = "Aspecto de SexyMap, movible y configurable desde DragonUI."
L["Minimap mode changed. Reload UI to apply?"] = "Modo de minimapa cambiado. ¿Recargar interfaz para aplicar?"

-- SexyMap slash commands
L["SexyMap compatibility mode has been reset. Reload UI to choose again."] = "El modo de compatibilidad SexyMap se ha restablecido. Recarga la interfaz para elegir de nuevo."
L["Current SexyMap mode: |cFFFFFF00%s|r"] = "Modo SexyMap actual: |cFFFFFF00%s|r"
L["No SexyMap mode selected (SexyMap not detected or not yet chosen)."] = "No se ha seleccionado modo SexyMap (SexyMap no detectado o aún no elegido)."
L["Show current SexyMap compatibility mode"] = "Mostrar modo de compatibilidad SexyMap actual"
L["Reset SexyMap mode choice (re-prompts on reload)"] = "Restablecer la elección de modo SexyMap (vuelve a preguntar al recargar)"
L["Loaded addons:"] = "Addons cargados:"

-- ============================================================================
-- STATIC POPUPS (shared between modules)
-- ============================================================================

L["Changing this setting requires a UI reload to apply correctly."] = "Cambiar esta opción requiere recargar la interfaz para aplicarse correctamente."
L["Reload UI"] = "Recargar Interfaz"
L["Not Now"] = "Ahora No"
L["Disable"] = "Desactivar"
L["Ignore"] = "Ignorar"
L["Skip"] = "Omitir"
L["The Blizzard option |cFFFFFF00Party/Arena Background|r is enabled. This conflicts with DragonUI's party frames."] = "La opción de Blizzard |cFFFFFF00Fondo de Grupo/Arena|r está activada. Esto entra en conflicto con los marcos de grupo de DragonUI."
L["Disable it now?"] = "¿Desactivarla ahora?"
L["Some interface settings are not configured optimally for DragonUI."] = "Algunas opciones de interfaz no están configuradas de forma óptima para DragonUI."
L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] = "Esto incluye opciones que entran en conflicto con DragonUI y opciones recomendadas para una mejor experiencia visual."
L["Affected settings:"] = "Opciones afectadas:"
L["Some interface settings are not configured optimally for DragonUI. Do you want to fix them?"] = "Algunas opciones de interfaz no están configuradas de forma óptima para DragonUI. ¿Quieres corregirlas?"
L["Do you want to fix them now?"] = "¿Quieres corregirlas ahora?"
L["Party/Arena Background"] = "Fondo de Grupo/Arena"
L["Default Status Text"] = "Texto de estado predeterminado"
L["Conflict"] = "Conflicto"
L["Recommended"] = "Recomendado"

-- Bag Sort
L["Sort Bags"] = "Ordenar Bolsas"
L["Sort Bank"] = "Ordenar Banco"
L["Sort Items"] = "Ordenar Objetos"
L["Click to sort items by type, rarity, and name."] = "Clic para ordenar objetos por tipo, rareza y nombre."
L["Clear Locked Slots"] = "Limpiar Slots Bloqueados"
L["Click to clear all locked bag slots."] = "Clic para limpiar todos los slots bloqueados de bolsas."
L["Alt+LeftClick any bag slot (item or empty) to lock or unlock it."] = "Alt+Clic izquierdo en cualquier slot de bolsa (con objeto o vacío) para bloquearlo o desbloquearlo."
L["Click the lock-clear button to remove all locked slots."] = "Haz clic en el botón de limpiar bloqueos para quitar todos los slots bloqueados."
L["Hover an item or slot, then type /sortlock."] = "Pasa el cursor sobre un objeto o slot y luego escribe /sortlock."
L["Slot locked (bag %d, slot %d)."] = "Slot bloqueado (bolsa %d, slot %d)."
L["Slot unlocked (bag %d, slot %d)."] = "Slot desbloqueado (bolsa %d, slot %d)."
L["Could not clear locks (config not ready)."] = "No se pudieron limpiar los bloqueos (configuración no lista)."
L["Cleared all sort-locked slots."] = "Se limpiaron todos los slots bloqueados del ordenado."

-- Guild Bank Sort
L["You must be at the guild bank."] = "Debes estar en el banco de hermandad."
L["Could not determine the current guild bank tab."] = "No se pudo determinar la pestaña actual del banco de hermandad."
L["You need full deposit and withdraw access to this tab to sort it."] = "Necesitas acceso completo de depósito y retiro en esta pestaña para ordenarla."
L["This guild bank tab is already sorted!"] = "¡Esta pestaña del banco de hermandad ya está ordenada!"
L["Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."] = "¿Ordenar esta pestaña del banco de hermandad? Dependiendo de tu servidor, esto puede quedar registrado y contar contra el límite de retiro compartido de tu hermandad, igual que si movieras los objetos a mano."
L["Sort"] = "Ordenar"
L["Click to sort items in the currently open guild bank tab."] = "Haz clic para ordenar los objetos de la pestaña del banco de hermandad actualmente abierta."
L["Never moves items between tabs."] = "Nunca mueve objetos entre pestañas."
L["Sort Guild Bank Tab"] = "Ordenar pestaña del banco de hermandad"

-- Micromenu Latency
L["Network"] = "Red"
L["Latency"] = "Latencia"

-- ============================================================================
-- STABILIZATION PATCH STRINGS
-- ============================================================================

L["/dragonui debug on|off|status - Toggle diagnostic logging"] = "/dragonui debug on|off|status - Activar o desactivar el registro de diagnóstico"
L["Usage: /dragonui debug on|off|status"] = "Uso: /dragonui debug on|off|status"
L["Enable debug mode first with /dragonui debug on"] = "Activa primero el modo depuración con /dragonui debug on"
L["Debug mode is %s"] = "El modo depuración está %s"
L["Debug mode enabled"] = "Modo depuración activado"
L["Debug mode disabled"] = "Modo depuración desactivado"
L["enabled"] = true
L["disabled"] = true
L["Enabled"] = "Activado"
L["Disabled"] = "Desactivado"
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
L["Registered Modules:"] = "Módulos registrados:"
L["No modules registered in ModuleRegistry"] = "No hay módulos registrados en ModuleRegistry"
L["load-once"] = "cargar una vez"
L["%s will disable after /reload because its secure hooks cannot be removed safely."] = "%s se desactivará tras /reload porque sus hooks seguros no pueden eliminarse de forma segura."
L["%s uses permanent secure hooks and will fully disable after /reload."] = "%s usa hooks seguros permanentes y se desactivará por completo tras /reload."
L["%s remains active until /reload because its secure hooks cannot be removed safely."] = "%s seguirá activo hasta /reload porque sus hooks seguros no pueden eliminarse de forma segura."
L["Cooldown Text"] = "Texto de reutilización"
L["Cooldown text on action buttons"] = "Texto de reutilización en los botones de acción"
L["Cast Bar"] = "Barra de lanzamiento"
L["Custom player, target, and focus cast bars"] = "Barras de lanzamiento personalizadas para jugador, objetivo y foco"
L["Multicast"] = "Multicast"
L["Shaman totem bar positioning and styling"] = "Posicionamiento y estilo de la barra de tótems de chamán"
L["Player Frame"] = "Marco del jugador"
L["Dragonflight-styled boss target frames"] = "Marcos de objetivo de jefe con estilo Dragonflight"
L["Dragonflight-styled player unit frame"] = "Marco de unidad del jugador con estilo Dragonflight"
L["ModuleRegistry:Register requires name and moduleTable"] = "ModuleRegistry:Register requiere name y moduleTable"
L["ModuleRegistry: Module already registered -"] = "ModuleRegistry: Módulo ya registrado -"
L["ModuleRegistry: Registered module -"] = "ModuleRegistry: Módulo registrado -"
L["order:"] = "orden:"
L["ModuleRegistry: Refresh failed for"] = "ModuleRegistry: Falló la actualización para"
L["ModuleRegistry: Unknown module -"] = "ModuleRegistry: Módulo desconocido -"
L["ModuleRegistry: Enabled -"] = "ModuleRegistry: Activado -"
L["ModuleRegistry: Disabled -"] = "ModuleRegistry: Desactivado -"
L["CombatQueue:Add requires id and func"] = "CombatQueue:Add requiere id y func"
L["CombatQueue: Registered PLAYER_REGEN_ENABLED"] = "CombatQueue: PLAYER_REGEN_ENABLED registrado"
L["CombatQueue: Queued operation -"] = "CombatQueue: Operación en cola -"
L["CombatQueue: Removed operation -"] = "CombatQueue: Operación eliminada -"
L["CombatQueue: Processing"] = "CombatQueue: Procesando"
L["queued operations"] = "operaciones en cola"
L["CombatQueue: Failed to execute"] = "CombatQueue: Error al ejecutar"
L["CombatQueue: Executed -"] = "CombatQueue: Ejecutado -"
L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"] = "CombatQueue: PLAYER_REGEN_ENABLED cancelado"
L["CombatQueue: Immediate execution failed -"] = "CombatQueue: Falló la ejecución inmediata -"

-- ============================================================================
-- RELEASE PREP STRINGS
-- ============================================================================

L["Buttons"] = "Botones"
L["Action button styling and enhancements"] = "Estilo y mejoras de botones de acción"
L["Dark Mode"] = "Modo Oscuro"
L["Darken UI borders and chrome"] = "Oscurecer bordes y elementos de la interfaz"
L["Item Quality"] = "Calidad de Objeto"
L["Color item borders by quality in bags, character panel, bank, and merchant"] = "Colorear los bordes de objetos por calidad en bolsas, personaje, banco y mercader"
L["Key Binding"] = "Atajos de Teclado"
L["LibKeyBound integration for intuitive keybinding"] = "Integración con LibKeyBound para asignación de teclas intuitiva"
L["Buff Frame"] = "Marco de Beneficios"
L["Custom buff frame styling, positioning and toggle button"] = "Estilo, posición y botón de alternancia personalizados para beneficios"
L["Chat Mods"] = "Mejoras de Chat"
L["Chat enhancements: hide buttons, editbox position, URL copy, chat copy, link hover, tell target"] = "Mejoras de chat: ocultar botones, posición de caja de texto, copiar URL, copiar chat, enlaces al pasar el cursor y susurrar al objetivo"
L["Bag Sort"] = "Ordenar Bolsas"
L["Sort bags and bank items with buttons"] = "Ordenar bolsas y banco con botones"
L["%s any bag slot (item or empty) to lock or unlock it."] = "%s en cualquier casilla de bolsa (con objeto o vacía) para bloquearla o desbloquearla."
L["Alt"] = "Alt"
L["Ctrl"] = "Ctrl"
L["Shift"] = "Mayús"
L["Left Click"] = "Clic izquierdo"
L["Right Click"] = "Clic derecho"
L["Middle Click"] = "Clic central"
L["Bag Skin"] = "Apariencia de bolsas"
L["Retail-style skin for Blizzard bag windows"] = "Apariencia estilo Retail para las ventanas de bolsas de Blizzard"
L["Combuctor"] = "Combuctor"
L["All-in-one bag replacement with filtering and search"] = "Reemplazo de bolsas todo en uno con filtros y búsqueda"
L["Stance Bar"] = "Barra de Posturas"
L["Vehicle"] = "Vehículo"
L["Vehicle interface enhancements"] = "Mejoras de la interfaz de vehículo"
L["Pet Bar"] = "Barra de Mascota"
L["Micro Menu"] = "Micromenú"
L["Main Bars"] = "Barras Principales"
L["Main action bars, status bars, scaling and positioning"] = "Barras de acción principales, barras de estado, escalado y posicionamiento"
L["Hide Blizzard"] = "Ocultar Blizzard"
L["Hide default Blizzard UI elements"] = "Ocultar elementos de interfaz predeterminados de Blizzard"
L["Minimap"] = "Minimapa"
L["Custom minimap styling, positioning, tracking icons and calendar"] = "Estilo, posicionamiento, iconos de rastreo y calendario personalizados para el minimapa"
L["Quest tracker positioning and styling"] = "Posicionamiento y estilo del rastreador de misiones"
L["Tooltip"] = "Tooltip"
L["Enhanced tooltip styling with class colors and health bars"] = "Estilo mejorado del tooltip con colores de clase y barras de salud"
L["Nameplates"] = "Placas de nombre"
L["Apply DragonUI nameplate styling."] = "Aplica el estilo DragonUI a las placas de nombre."
L["Unit Frame Layers"] = "Capas de Marcos de Unidad"
L["Heal prediction, absorb shields, and animated health loss on unit frames"] = "Predicción de sanación, escudos de absorción y pérdida de salud animada en marcos de unidad"
L["Stance/shapeshift bar positioning and styling"] = "Posicionamiento y estilo de la barra de posturas/cambiaformas"
L["Pet action bar positioning and styling"] = "Posicionamiento y estilo de la barra de acción de mascota"
L["Micro menu and bags system styling and positioning"] = "Estilo y posicionamiento del micromenú y sistema de bolsas"
L["Sort complete."] = "Ordenación completada."
L["Sort already in progress."] = "La ordenación ya está en progreso."
L["Bags already sorted!"] = "¡Las bolsas ya están ordenadas!"
L["You must be at the bank."] = "Debes estar en el banco."
L["Bank already sorted!"] = "¡El banco ya está ordenado!"
L["Reputation: "] = "Reputación: "
L["Error in SafeCall:"] = "Error en SafeCall:"

L["Copy Text"] = "Copiar texto"

-- Version Check Module
L["Version Check"] = "Control de Versión"
L["Broadcast and detect addon version updates across group members"] = "Detecta actualizaciones del addon entre miembros del grupo enviando y recibiendo la versión"
