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

local L = LibStub("AceLocale-3.0"):NewLocale("DragonUI", "deDE")
if not L then return end

-- ============================================================================
-- CORE / GENERAL
-- ============================================================================

-- Combat lockdown messages
L["Cannot toggle editor mode during combat!"] = "Editor-Modus kann im Kampf nicht umgeschaltet werden!"
L["Cannot reset positions during combat!"] = "Positionen können im Kampf nicht zurückgesetzt werden!"
L["Cannot toggle keybind mode during combat!"] = "Tastenbelegungsmodus kann im Kampf nicht umgeschaltet werden!"
L["Cannot move frames during combat!"] = "Fenster können im Kampf nicht bewegt werden!"
L["Cannot open options in combat."] = "Optionen können im Kampf nicht geöffnet werden."
L["Options panel not available. Try /reload."] = "Optionsfeld nicht verfügbar. Versuche /reload."

-- Module availability
L["Editor mode not available."] = "Editor-Modus ist nicht verfügbar."
L["Keybind mode not available."] = "Tastenbelegungsmodus ist nicht verfügbar."
L["Vehicle debug not available"] = "Fahrzeug-Debug ist nicht verfügbar"
L["KeyBinding module not available"] = "Tastenbelegungs-Modul ist nicht verfügbar"
L["Unable to open configuration"] = "Konfiguration kann nicht geöffnet werden"
L["Commands: /dragonui config, /dragonui edit"] = "Befehle: /dragonui config, /dragonui edit"
L["Reset position: %s"] = "Position zurückgesetzt: %s"
L["All positions reset to defaults"] = "Alle Positionen auf Standardwerte zurückgesetzt"
L["Editor mode enabled - Drag frames to reposition"] = "Editormodus aktiviert - Rahmen ziehen zum Neupositionieren"
L["Editor mode disabled - Positions saved"] = "Editormodus deaktiviert - Positionen gespeichert"
L["Minimap module restored to Blizzard defaults"] = "Minimap-Modul auf Blizzard-Standardwerte zurückgesetzt"
L["All action bar scales reset to default values"] = "Alle Aktionsleisten-Skalierungen auf Standardwerte zurückgesetzt"
L["Minimap position reset to default"] = "Minimap-Position auf Standard zurückgesetzt"
L["Targeting: %s"] = "Zielt auf: %s"
L["XP: %d/%d"] = "EP: %d/%d"
L["GROUP %d"] = "GRUPPE %d"
L["XP: "] = "EP: "
L["Remaining: "] = "Verbleibend: "
L["Rested: "] = "Ausgeruht: "

-- Errors
L["Error executing pending operation:"] = "Fehler beim Ausführen der ausstehenden Operation:"
L["Error -- Addon 'DragonUI_Options' not found or is disabled."] = "Fehler -- Addon 'DragonUI_Options' wurde nicht gefunden oder ist deaktiviert."

-- ============================================================================
-- SLASH COMMANDS / HELP
-- ============================================================================

L["Unknown command: "] = "Unbekannter Befehl: "
L["=== DragonUI Commands ==="] = "=== DragonUI-Befehle ==="
L["/dragonui or /dui - Open configuration"] = "/dragonui oder /dui - Konfiguration öffnen"
L["/dragonui config - Open configuration"] = "/dragonui config - Konfiguration öffnen"
L["/dragonui edit - Toggle editor mode (move UI elements)"] = "/dragonui edit - Editor-Modus umschalten (UI-Elemente verschieben)"
L["/dragonui reset - Reset all positions to defaults"] = "/dragonui reset - Alle Positionen auf Standard zurücksetzen"
L["/dragonui reset <name> - Reset specific mover"] = "/dragonui reset <name> - Bestimmten Mover zurücksetzen"
L["/dragonui status - Show module status"] = "/dragonui status - Modulstatus anzeigen"
L["/dragonui kb - Toggle keybind mode"] = "/dragonui kb - Tastenbelegungsmodus umschalten"
L["/dragonui version - Show version info"] = "/dragonui version - Versionsinfo anzeigen"
L["/dragonui help - Show this help"] = "/dragonui help - Diese Hilfe anzeigen"
L["/rl - Reload UI"] = "/rl - UI neu laden"

-- ============================================================================
-- STATUS DISPLAY
-- ============================================================================

L["=== DragonUI Status ==="] = "=== DragonUI-Status ==="
L["Detected Modules:"] = "Erkannte Module:"
L["Loaded"] = "Geladen"
L["Not Loaded"] = "Nicht geladen"
L["Target Frame"] = true
L["Focus Frame"] = true
L["Party Frames"] = true
L["Cooldowns"] = true
L["Registered Movers: "] = "Registrierte Mover: "
L["Editable Frames: "] = "Bearbeitbare Frames: "
L["DragonUI Version: "] = "DragonUI-Version: "
L["Use /dragonui edit to enter edit mode, then right-click frames to reset."] = "Nutze /dragonui edit, um den Bearbeitungsmodus zu aktivieren, und klicke dann mit Rechtsklick auf Frames, um sie zurückzusetzen."

-- ============================================================================
-- EDITOR MODE
-- ============================================================================

L["Exit Edit Mode"] = "Bearbeitungsmodus beenden"
L["Reset All Positions"] = "Alle Positionen zurücksetzen"
L["Are you sure you want to reset all interface elements to their default positions?"] = "Bist du sicher, dass du alle Interface-Elemente auf ihre Standardpositionen zurücksetzen möchtest?"
L["Yes"] = "Ja"
L["No"] = "Nein"
L["UI elements have been repositioned. Reload UI to ensure all graphics display correctly?"] = "UI-Elemente wurden neu positioniert. UI neu laden, damit alle Grafiken korrekt angezeigt werden?"
L["Reload Now"] = "Jetzt neu laden"
L["Later"] = "Später"

-- Position presets (edit mode)
L["Position Presets"] = "Positions-Vorlagen"
L["Position Preset"] = "Positions-Vorlage"
L["Save"] = "Speichern"
L["Import"] = "Importieren"
L["Cancel"] = "Abbrechen"
L["Load"] = "Laden"
L["Delete"] = "Löschen"
L["Select All"] = "Alles auswählen"
L["Click to load"] = "Klicken zum Laden"
L["No position presets saved yet."] = "Noch keine Positions-Vorlagen gespeichert."
L["Load position preset '%s'? This will overwrite your current element positions."] = "Vorlage '%s' laden? Die aktuellen Elementpositionen werden überschrieben."
L["Delete position preset '%s'? This cannot be undone."] = "Vorlage '%s' löschen? Dies kann nicht rückgängig gemacht werden."
L["Enter a name for the imported position preset:"] = "Name für die importierte Positions-Vorlage eingeben:"
L["Imported Position Preset"] = "Importierte Positions-Vorlage"
L["Position preset saved: "] = "Positions-Vorlage gespeichert: "
L["Position preset loaded: "] = "Positions-Vorlage geladen: "
L["Position preset deleted: "] = "Positions-Vorlage gelöscht: "
L["Position preset imported: "] = "Positions-Vorlage importiert: "
L["Export Position Preset"] = "Positions-Vorlage exportieren"
L["Import Position Preset"] = "Positions-Vorlage importieren"
L["Invalid position preset string."] = "Ungültige Positions-Vorlage."
L["Not a valid DragonUI position preset string."] = "Keine gültige DragonUI-Positions-Vorlage."
L["Failed to export position preset."] = "Export der Positions-Vorlage fehlgeschlagen."
L["Save New Preset"] = "Neue Vorlage speichern"
L["Load Preset"] = "Vorlage laden"
L["Delete Preset"] = "Vorlage löschen"
L["Export Preset"] = "Vorlage exportieren"
L["Import Preset"] = "Vorlage importieren"

-- ============================================================================
-- KEYBINDING MODULE
-- ============================================================================

L["LibKeyBound-1.0 not found or failed to load:"] = "LibKeyBound-1.0 nicht gefunden oder Laden fehlgeschlagen:"
L["Commands:"] = "Befehle:"
L["/dukb - Toggle keybinding mode"] = "/dukb - Tastenbelegungsmodus umschalten"
L["/dukb help - Show this help"] = "/dukb help - Diese Hilfe anzeigen"
L["Module disabled."] = "Modul deaktiviert."
L["Keybinding mode activated. Hover over buttons and press keys to bind them."] = "Tastenbelegungsmodus aktiviert. Fahre über Buttons und drücke Tasten, um sie zu belegen."
L["Keybinding mode deactivated."] = "Tastenbelegungsmodus deaktiviert."

-- ============================================================================
-- GAME MENU
-- ============================================================================


-- ============================================================================
-- MINIMAP MODULE
-- ============================================================================

L["DragonUI: Minimap module restored to Blizzard defaults"] = "DragonUI: Minimap-Modul auf Blizzard-Standard zurückgesetzt"
L["Minimap Buttons"] = "Minikarten-Schaltflachen"
L["Minimap Buttons Collector"] = "Minikarten-Schaltflachen"
L["Left-click to show or hide minimap addon buttons."] = "Linksklick, um Minikarten-Addon-Schaltflachen zu offnen."
L["Right-click to open DragonUI settings."] = "Rechtsklick, um DragonUI-Einstellungen zu offnen."

-- ============================================================================
-- EDITOR MODE LABELS (displayed on mover overlays)
-- ============================================================================

L["MainBar"] = "Hauptleiste"
L["RightBar"] = "Rechte Leiste"
L["LeftBar"] = "Linke Leiste"
L["BottomBarLeft"] = "Unten links"
L["BottomBarRight"] = "Unten rechts"
L["XPBar"] = "EP-Leiste"
L["RepBar"] = "Ruf-Leiste"
L["MinimapFrame"] = "Minimap"
L["LFGFrame"] = "Dungeon Auge"
L["PlayerFrame"] = "Spieler"
L["ManaBar"] = "Mana-Leiste"
L["PetFrame"] = "Begleiter"
L["ToF"] = "Ziel des Fokus"
L["tot"] = "Ziel des Ziels"
L["ToT"] = "Ziel des Ziels"
L["fot"] = "Ziel des Fokus"
L["PartyFrames"] = "Gruppe"
L["TargetFrame"] = "Ziel"
L["FocusFrame"] = "Fokus"
L["TargetCastbar"] = "Ziel-Zauberleiste"
L["FocusCastbar"] = "Fokus-Zauberleiste"
L["BagsBar"] = "Taschen"
L["MicroMenu"] = "Mikromenü"
L["VehicleExitOverlay"] = "Fahrzeug verlassen"
L["StanceOverlay"] = "Haltungsleiste"
L["petbar"] = "Begleiterleiste"
L["boss"] = "Boss-Rahmen"
L["Boss Frames"] = "Boss-Rahmen"
L["Boss1Frame"] = "Boss-Rahmen"
L["Boss2Frame"] = "Boss-Rahmen"
L["Boss3Frame"] = "Boss-Rahmen"
L["Boss4Frame"] = "Boss-Rahmen"
L["TotemBarOverlay"] = "Totemleiste"
L["PlayerCastbar"] = "Zauberleiste"
L["TooltipWidget"] = "Tooltip"
L["Auras"] = "Auren"
L["WeaponEnchants"] = "Waffenverzauberungen"
L["Loot Roll"] = "Beute würfeln"
L["Quest Tracker"] = "Questverfolgung"

-- Mover tooltip strings
L["Drag to move"] = "Ziehen zum Verschieben"
L["Animated minimap border effects for DragonUI."] = "Animierte Minimap-Rahmeneffekte für DragonUI."
L["Right-click to reset"] = "Rechtsklick zum Zurücksetzen"
L["Status Tooltip:"] = "Status-Tooltip:"
L["Top"] = "Oben"
L["Bottom"] = "Unten"
L["Left"] = "Links"
L["Right"] = "Rechts"
L["Error Messages"] = "Fehlermeldungen"
L["ErrorMessages"] = "Fehlermeldungen"

-- Editor mode system messages
L["All editable frames shown for editing"] = "Alle bearbeitbaren Frames zum Bearbeiten angezeigt"
L["All editable frames hidden, positions saved"] = "Alle bearbeitbaren Frames ausgeblendet, Positionen gespeichert"

-- ============================================================================
-- COMPATIBILITY MODULE
-- ============================================================================

-- Conflict warning popup
L["DragonUI Conflict Warning"] = "DragonUI-Konfliktwarnung"
L["The addon |cFFFFFF00%s|r conflicts with DragonUI."] = "Das Addon |cFFFFFF00%s|r kollidiert mit DragonUI."
L["Reason:"] = "Grund:"
L["Disable the conflicting addon now?"] = "Das konfliktverursachende Addon jetzt deaktivieren?"
L["Keep Both"] = "Beide behalten"
L["DragonUI - D3D9Ex Warning"] = "DragonUI - D3D9Ex-Warnung"
L["DragonUI detected that your client is using D3D9Ex."] = "DragonUI hat erkannt, dass dein Client D3D9Ex verwendet."
L["DragonUI's action bar system is not compatible with D3D9Ex."] = "Das Aktionsleisten-System von DragonUI ist nicht mit D3D9Ex kompatibel."
L["Some DragonUI action bar textures will be missing while this mode is active."] = "Einige Texturen der DragonUI-Aktionsleisten fehlen, solange dieser Modus aktiv ist."
L["If you want to disable this mode, open WTF\\Config.wtf."] = "Wenn du diesen Modus deaktivieren willst, öffne WTF\\Config.wtf."
L["Delete this line:"] = "Lösche diese Zeile:"
L["Or replace it with:"] = "Oder ersetze sie durch:"
L["Hide Gryphons"] = "Greifen ausblenden"
L["Understood"] = "Verstanden"
L["DragonUI - UnitFrameLayers Detected"] = "DragonUI - UnitFrameLayers erkannt"
L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] = "DragonUI enthält die Unit-Frame-Layers-Funktion bereits (Heilvorhersage, Absorptionsschilde und animierter Lebensverlust)."
L["Choose how to resolve this overlap:"] = "Wähle, wie diese Überschneidung gelöst werden soll:"
L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] = "DragonUI nutzen: externes UnitFrameLayers deaktivieren und DragonUI-Layer aktivieren."
L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."] = "Beide deaktivieren: externes UnitFrameLayers deaktivieren und DragonUI-Layer ausgeschaltet lassen."
L["Use DragonUI"] = "DragonUI nutzen"
L["Disable Both"] = "Beide deaktivieren"
L["Use DragonUI Unit Frame Layers"] = "DragonUI Unit Frame Layers verwenden"
L["Disable both Unit Frame Layers"] = "Beide Unit Frame Layers deaktivieren"
L["DragonUI - Party Frame Issue"] = true
L["You joined a party while in combat. Due to CompactRaidFrame taint issues, party frames may not display correctly."] = true
L["Reload the UI to fix party frame display?"] = true

-- Conflict reasons
L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = "Kollidiert mit DragonUIs benutzerdefinierten Einheiten-Rahmen-Texturen und dem Machtleistensystem."
L["Known taint issues when manipulating party frames during combat. DragonUI provides automatic fixes."] = "Bekannte Kontaminationsprobleme beim Manipulieren von Gruppenrahmen im Kampf. DragonUI bietet automatische Korrekturen."
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = "Setzt Minimap-Maske und Markierungs-Texturen zurück. DragonUI wendet seine benutzerdefinierten Texturen automatisch erneut an."
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = "SexyMap verändert die Minimap-Rahmen, Form und Zonentexte, was mit dem Minimap-Modul von DragonUI kollidiert."

-- SexyMap compatibility popup
L["DragonUI - SexyMap Detected"] = "DragonUI - SexyMap erkannt"
L["Which minimap do you want to use?"] = "Welche Minikarte möchtest du verwenden?"
L["SexyMap"] = "SexyMap"
L["DragonUI"] = "DragonUI"
L["Hybrid"] = "Hybrid"
L["Recommended"] = "Empfohlen"

-- SexyMap options panel
L["SexyMap Compatibility"] = "SexyMap-Kompatibilität"
L["Minimap Mode"] = "Minikarten-Modus"
L["Choose how DragonUI and SexyMap share the minimap."] = "Wähle, wie DragonUI und SexyMap die Minikarte teilen."
L["Requires UI reload to apply."] = "Erfordert UI-Neuladen."
L["Uses SexyMap for the minimap."] = "Verwendet SexyMap für die Minikarte."
L["Uses DragonUI for the minimap."] = "Verwendet DragonUI für die Minikarte."
L["SexyMap visuals with DragonUI editor and positioning."] = "SexyMap-Optik, bewegbar und konfigurierbar über DragonUI."
L["Minimap mode changed. Reload UI to apply?"] = "Minikarten-Modus geändert. UI neu laden?"

-- SexyMap slash commands
L["SexyMap compatibility mode has been reset. Reload UI to choose again."] = "Der SexyMap-Kompatibilitätsmodus wurde zurückgesetzt. Lade die UI neu, um erneut zu wählen."
L["Current SexyMap mode: |cFFFFFF00%s|r"] = "Aktueller SexyMap-Modus: |cFFFFFF00%s|r"
L["No SexyMap mode selected (SexyMap not detected or not yet chosen)."] = "Kein SexyMap-Modus ausgewählt (SexyMap nicht erkannt oder noch nicht gewählt)."
L["Show current SexyMap compatibility mode"] = "Aktuellen SexyMap-Kompatibilitätsmodus anzeigen"
L["Reset SexyMap mode choice (re-prompts on reload)"] = "SexyMap-Modusauswahl zurücksetzen (fragt beim Neuladen erneut)"
L["Loaded addons:"] = "Geladene Addons:"

-- ============================================================================
-- STATIC POPUPS (shared between modules)
-- ============================================================================

L["Changing this setting requires a UI reload to apply correctly."] = "Das Ändern dieser Einstellung erfordert ein Neuladen der UI, damit es korrekt angewendet wird."
L["Reload UI"] = "UI neu laden"
L["Not Now"] = "Nicht jetzt"
L["Disable"] = "Deaktivieren"
L["Ignore"] = "Ignorieren"
L["Skip"] = "Überspringen"
L["The Blizzard option |cFFFFFF00Party/Arena Background|r is enabled. This conflicts with DragonUI's party frames."] = "Die Blizzard-Option |cFFFFFF00Gruppen/Arena-Hintergrund|r ist aktiviert. Dies steht im Konflikt mit DragonUIs Gruppenfenstern."
L["Disable it now?"] = "Jetzt deaktivieren?"
L["Some interface settings are not configured optimally for DragonUI."] = "Einige Interface-Einstellungen sind für DragonUI nicht optimal konfiguriert."
L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] = "Dazu gehören Einstellungen, die mit DragonUI kollidieren, sowie empfohlene Einstellungen für die beste visuelle Darstellung."
L["Affected settings:"] = "Betroffene Einstellungen:"
L["Some interface settings are not configured optimally for DragonUI. Do you want to fix them?"] = "Einige Interface-Einstellungen sind für DragonUI nicht optimal konfiguriert. Möchtest du sie korrigieren?"
L["Do you want to fix them now?"] = "Möchtest du sie jetzt korrigieren?"
L["Party/Arena Background"] = "Gruppen/Arena-Hintergrund"
L["Default Status Text"] = "Standard-Statustext"
L["Conflict"] = "Konflikt"
L["Recommended"] = "Empfohlen"

-- Bag Sort
L["Sort Bags"] = "Taschen sortieren"
L["Sort Bank"] = "Bank sortieren"
L["Sort Items"] = "Gegenstände sortieren"
L["Click to sort items by type, rarity, and name."] = "Klicken, um Gegenstände nach Typ, Seltenheit und Name zu sortieren."
L["Clear Locked Slots"] = "Gesperrte Slots löschen"
L["Click to clear all locked bag slots."] = "Klicken, um alle gesperrten Taschenslots zu löschen."
L["Alt+LeftClick any bag slot (item or empty) to lock or unlock it."] = "Alt+Linksklick auf einen Taschenslot (mit Gegenstand oder leer), um ihn zu sperren oder zu entsperren."
L["Click the lock-clear button to remove all locked slots."] = "Klicke auf die Sperren-Löschen-Schaltfläche, um alle gesperrten Slots zu entfernen."
L["Hover an item or slot, then type /sortlock."] = "Bewege die Maus über einen Gegenstand oder Slot und tippe dann /sortlock."
L["Slot locked (bag %d, slot %d)."] = "Slot gesperrt (Tasche %d, Slot %d)."
L["Slot unlocked (bag %d, slot %d)."] = "Slot entsperrt (Tasche %d, Slot %d)."
L["Could not clear locks (config not ready)."] = "Sperren konnten nicht gelöscht werden (Konfiguration nicht bereit)."
L["Cleared all sort-locked slots."] = "Alle für das Sortieren gesperrten Slots wurden gelöscht."

-- Micromenu Latency
L["Network"] = "Netzwerk"
L["Latency"] = "Latenz"

-- ============================================================================
-- STABILIZATION PATCH STRINGS
-- ============================================================================

L["/dragonui debug on|off|status - Toggle diagnostic logging"] = "/dragonui debug on|off|status - Diagnoseprotokoll umschalten"
L["Usage: /dragonui debug on|off|status"] = "Verwendung: /dragonui debug on|off|status"
L["Enable debug mode first with /dragonui debug on"] = "Aktiviere zuerst den Debug-Modus mit /dragonui debug on"
L["Debug mode is %s"] = "Debug-Modus ist %s"
L["Debug mode enabled"] = "Debug-Modus aktiviert"
L["Debug mode disabled"] = "Debug-Modus deaktiviert"
L["enabled"] = true
L["disabled"] = true
L["Enabled"] = "Aktiviert"
L["Disabled"] = "Deaktiviert"
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
L["Registered Modules:"] = "Registrierte Module:"
L["No modules registered in ModuleRegistry"] = "Keine Module in der ModuleRegistry registriert"
L["load-once"] = "einmal laden"
L["%s will disable after /reload because its secure hooks cannot be removed safely."] = "%s wird nach /reload deaktiviert, weil seine sicheren Hooks nicht sicher entfernt werden können."
L["%s uses permanent secure hooks and will fully disable after /reload."] = "%s verwendet permanente sichere Hooks und wird nach /reload vollständig deaktiviert."
L["%s remains active until /reload because its secure hooks cannot be removed safely."] = "%s bleibt bis /reload aktiv, weil seine sicheren Hooks nicht sicher entfernt werden können."
L["Cooldown Text"] = "Abklingzeit-Text"
L["Cooldown text on action buttons"] = "Abklingzeit-Text auf Aktionsleistenknöpfen"
L["Cast Bar"] = "Zauberleiste"
L["Custom player, target, and focus cast bars"] = "Benutzerdefinierte Zauberleisten für Spieler, Ziel und Fokus"
L["Multicast"] = "Multicast"
L["Shaman totem bar positioning and styling"] = "Positionierung und Stil der Schamanen-Totemleiste"
L["Player Frame"] = "Spielerframe"
L["Dragonflight-styled boss target frames"] = "Boss-Zielframes im Dragonflight-Stil"
L["Dragonflight-styled player unit frame"] = "Spieler-Unitframe im Dragonflight-Stil"
L["ModuleRegistry:Register requires name and moduleTable"] = "ModuleRegistry:Register benötigt name und moduleTable"
L["ModuleRegistry: Module already registered -"] = "ModuleRegistry: Modul bereits registriert -"
L["ModuleRegistry: Registered module -"] = "ModuleRegistry: Modul registriert -"
L["order:"] = "Reihenfolge:"
L["ModuleRegistry: Refresh failed for"] = "ModuleRegistry: Aktualisierung fehlgeschlagen für"
L["ModuleRegistry: Unknown module -"] = "ModuleRegistry: Unbekanntes Modul -"
L["ModuleRegistry: Enabled -"] = "ModuleRegistry: Aktiviert -"
L["ModuleRegistry: Disabled -"] = "ModuleRegistry: Deaktiviert -"
L["CombatQueue:Add requires id and func"] = "CombatQueue:Add benötigt id und func"
L["CombatQueue: Registered PLAYER_REGEN_ENABLED"] = "CombatQueue: PLAYER_REGEN_ENABLED registriert"
L["CombatQueue: Queued operation -"] = "CombatQueue: Operation in Warteschlange -"
L["CombatQueue: Removed operation -"] = "CombatQueue: Operation entfernt -"
L["CombatQueue: Processing"] = "CombatQueue: Verarbeite"
L["queued operations"] = "Operationen in Warteschlange"
L["CombatQueue: Failed to execute"] = "CombatQueue: Ausführung fehlgeschlagen"
L["CombatQueue: Executed -"] = "CombatQueue: Ausgeführt -"
L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"] = "CombatQueue: PLAYER_REGEN_ENABLED abgemeldet"
L["CombatQueue: Immediate execution failed -"] = "CombatQueue: Sofortige Ausführung fehlgeschlagen -"

-- ============================================================================
-- RELEASE PREP STRINGS
-- ============================================================================

L["Buttons"] = "Schaltflächen"
L["Action button styling and enhancements"] = "Aktionsknopf-Styling und Verbesserungen"
L["Dark Mode"] = "Dunkelmodus"
L["Darken UI borders and chrome"] = "UI-Rahmen und Zierrat abdunkeln"
L["Item Quality"] = "Gegenstandsqualität"
L["Color item borders by quality in bags, character panel, bank, and merchant"] = "Gegenstandsrahmen in Taschen, Charakterfenster, Bank und beim Händler nach Qualität einfärben"
L["Key Binding"] = "Tastenbelegung"
L["LibKeyBound integration for intuitive keybinding"] = "LibKeyBound-Integration für intuitive Tastenbelegung"
L["Buff Frame"] = "Buff-Rahmen"
L["Custom buff frame styling, positioning and toggle button"] = "Benutzerdefiniertes Styling, Positionierung und Umschaltknopf für den Buff-Rahmen"
L["Chat Mods"] = "Chat-Mods"
L["Chat enhancements: hide buttons, editbox position, URL copy, chat copy, link hover, tell target"] = "Chat-Verbesserungen: Buttons ausblenden, Eingabefeld-Position, URL-Kopie, Chat-Kopie, Link-Hover und Ziel anflüstern"
L["Bag Sort"] = "Taschensortierung"
L["Sort bags and bank items with buttons"] = "Taschen- und Bankgegenstände per Knopf sortieren"
L["Combuctor"] = "Combuctor"
L["All-in-one bag replacement with filtering and search"] = "All-in-One-Taschenersatz mit Filtern und Suche"
L["Stance Bar"] = "Haltungsleiste"
L["Vehicle"] = "Fahrzeug"
L["Vehicle interface enhancements"] = "Verbesserungen der Fahrzeugoberfläche"
L["Pet Bar"] = "Begleiterleiste"
L["Micro Menu"] = "Mikromenü"
L["Main Bars"] = "Hauptleisten"
L["Main action bars, status bars, scaling and positioning"] = "Hauptaktionsleisten, Statusleisten, Skalierung und Positionierung"
L["Hide Blizzard"] = "Blizzard ausblenden"
L["Hide default Blizzard UI elements"] = "Standard-UI-Elemente von Blizzard ausblenden"
L["Minimap"] = "Minikarte"
L["Custom minimap styling, positioning, tracking icons and calendar"] = "Benutzerdefiniertes Minikarten-Styling, Positionierung, Verfolgungssymbole und Kalender"
L["Quest tracker positioning and styling"] = "Positionierung und Styling der Questverfolgung"
L["Tooltip"] = "Tooltip"
L["Enhanced tooltip styling with class colors and health bars"] = "Erweitertes Tooltip-Styling mit Klassenfarben und Lebensleisten"
L["Nameplates"] = "Namensplaketten"
L["Apply DragonUI nameplate styling."] = "Wendet das DragonUI-Design auf Namensplaketten an."
L["Unit Frame Layers"] = "Unit-Frame-Ebenen"
L["Heal prediction, absorb shields, and animated health loss on unit frames"] = "Heilvorhersage, Absorptionsschilde und animierter Lebensverlust auf Unit-Frames"
L["Stance/shapeshift bar positioning and styling"] = "Positionierung und Styling der Haltungs-/Gestaltwandlungsleiste"
L["Pet action bar positioning and styling"] = "Positionierung und Styling der Begleiter-Aktionsleiste"
L["Micro menu and bags system styling and positioning"] = "Styling und Positionierung von Mikromenü und Taschensystem"
L["Sort complete."] = "Sortierung abgeschlossen."
L["Sort already in progress."] = "Sortierung läuft bereits."
L["Bags already sorted!"] = "Taschen sind bereits sortiert!"
L["You must be at the bank."] = "Du musst an der Bank sein."
L["Bank already sorted!"] = "Bank ist bereits sortiert!"
L["Reputation: "] = "Ruf: "
L["Error in SafeCall:"] = "Fehler in SafeCall:"

L["Copy Text"] = "Text kopieren"

L["Version Check"] = "Versionsprüfung"
L["Notifies when other players have a different addon version"] = "Benachrichtigt, wenn andere Spieler eine andere Addon-Version haben"
