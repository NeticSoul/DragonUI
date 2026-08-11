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

local L = LibStub("AceLocale-3.0-DragonUI"):NewLocale("DragonUI", "deDE")
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
L["Target Frame"] = "Zielfenster"
L["Focus Frame"] = "Fokusfenster"
L["Party Frames"] = "Gruppenfenster"
L["Cooldowns"] = "Abklingzeiten"
L["Editable Frames: "] = "Bearbeitbare Frames: "
L["DragonUI Version: "] = "DragonUI-Version: "

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
L["ExtraBar1"] = "Extra-Leiste"
L["boss"] = "Boss-Rahmen"
L["Boss Frames"] = "Boss-Rahmen"
L["Boss1Frame"] = "Boss-Rahmen"
L["Boss2Frame"] = "Boss-Rahmen"
L["Boss3Frame"] = "Boss-Rahmen"
L["Boss4Frame"] = "Boss-Rahmen"
L["TotemBarOverlay"] = "Totemleiste"
L["PlayerCastbar"] = "Zauberleiste"
L["TooltipWidget"] = "Tooltip"
L["Buff"] = "Verstärkung"
L["Debuffs"] = "Schwächung"
L["WeaponEnchants"] = "Waffenverzauberungen"
L["Loot Roll"] = "Beute würfeln"
L["Quest Tracker"] = "Questverfolgung"

-- Mover tooltip strings
L["Drag to move"] = "Ziehen zum Verschieben"
L["Animated minimap border effects for DragonUI."] = "Animierte Minimap-Rahmeneffekte für DragonUI."
L["Right-click to reset"] = "Rechtsklick zum Zurücksetzen"
L["Click to reset"] = "Klick zum Zurücksetzen"
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

-- Conflict reasons
L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = "Kollidiert mit DragonUIs benutzerdefinierten Einheiten-Rahmen-Texturen und dem Machtleistensystem."
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = "Setzt Minimap-Maske und Markierungs-Texturen zurück. DragonUI wendet seine benutzerdefinierten Texturen automatisch erneut an."
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = "SexyMap verändert die Minimap-Rahmen, Form und Zonentexte, was mit dem Minimap-Modul von DragonUI kollidiert."
L["Reads native nameplate alpha to identify the target's plate; conflicts with DragonUI's default anti-dim behavior."] = "Nutzt die native Transparenz der Namensplakette, um die Zielplakette zu erkennen; kollidiert mit DragonUIs Standard-Anti-Abdunkelung."
L["Parents its cooldown icons to the native health bar; conflicts with DragonUI's default health-bar hiding."] = "Hängt seine Abklingzeit-Icons an die native Gesundheitsleiste; kollidiert mit DragonUIs Standard-Ausblendung dieser Leiste."

-- Nameplate addon compatibility popup
L["Detected |cFFFFFF00%s|r. Enable Nameplate Addon Compatibility so it works correctly?"] = "|cFFFFFF00%s|r erkannt. Namensplaketten-Addon-Kompatibilität aktivieren, damit es korrekt funktioniert?"
L["Detected |cFFFFFF00%s|r. Enable Nameplate Health Bar Compatibility so it works correctly?"] = "|cFFFFFF00%s|r erkannt. Namensplaketten-Gesundheitsleisten-Kompatibilität aktivieren, damit es korrekt funktioniert?"
L["Enable"] = "Aktivieren"

-- SexyMap compatibility popup
L["DragonUI - SexyMap Detected"] = "DragonUI - SexyMap erkannt"
L["Which minimap do you want to use?"] = "Welche Minikarte möchtest du verwenden?"
L["SexyMap"] = "SexyMap"
L["DragonUI"] = "DragonUI"
L["Hybrid"] = "Hybrid"

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

-- Sell Scrap
L["Sell Scrap"] = "Schrott verkaufen"
L["Open a merchant window first to sell scrap items."] = "Öffne zuerst ein Händlerfenster, um Schrott zu verkaufen."

-- Guild Bank Sort
L["You must be at the guild bank."] = "Du musst dich an der Gildenbank befinden."
L["Could not determine the current guild bank tab."] = "Die aktuelle Gildenbank-Registerkarte konnte nicht ermittelt werden."
L["You need full deposit and withdraw access to this tab to sort it."] = "Du benötigst vollen Einzahlungs- und Abhebungszugriff auf diese Registerkarte, um sie zu sortieren."
L["This guild bank tab is already sorted!"] = "Diese Gildenbank-Registerkarte ist bereits sortiert!"
L["Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."] = "Diese Gildenbank-Registerkarte sortieren? Je nach Server kann dies protokolliert werden und auf das gemeinsame Abhebungslimit deiner Gilde angerechnet werden, genau wie beim manuellen Verschieben von Gegenständen."
L["Sort"] = "Sortieren"
L["Click to sort items in the currently open guild bank tab."] = "Klicke, um die Gegenstände in der aktuell geöffneten Gildenbank-Registerkarte zu sortieren."
L["Never moves items between tabs."] = "Verschiebt niemals Gegenstände zwischen Registerkarten."
L["Sort Guild Bank Tab"] = "Gildenbank-Registerkarte sortieren"

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
L["enabled"] = "aktiviert"
L["disabled"] = "deaktiviert"
L["Enabled"] = "Aktiviert"
L["Disabled"] = "Deaktiviert"
L["Legacy refresh failed for"] = "Alt-Aktualisierung fehlgeschlagen für"
L["Bonus Action Button %d"] = "Bonus-Aktionsknopf %d"
L["Stance Button %d"] = "Haltungsknopf %d"
L["Pet Action Button %d"] = "Begleiter-Aktionsknopf %d"
L["Multicast Button %d"] = "Multicast-Knopf %d"
L["Totem Call Button"] = "Totemruf-Knopf"
L["Totem Recall Button"] = "Totemrückruf-Knopf"
L["Bottom Left Button"] = "Knopf unten links"
L["Bottom Right Button"] = "Knopf unten rechts"
L["Right Button"] = "Rechter Knopf"
L["Left Button"] = "Linker Knopf"
L["Totem Bar"] = "Totemleiste"
L["Test Pet"] = "Test-Begleiter"
L["=== TargetFrame children (depth 3) ==="] = "=== TargetFrame-Kinder (Tiefe 3) ==="
L["=== FocusFrame children (depth 3) ==="] = "=== FocusFrame-Kinder (Tiefe 3) ==="
L["BG texture not found"] = "Hintergrundtextur nicht gefunden"
L["BG tinted RED"] = "Hintergrund ROT eingefärbt"
L["BG tinted GREEN"] = "Hintergrund GRÜN eingefärbt"
L["BG color reset"] = "Hintergrundfarbe zurückgesetzt"
L["=== BANK SCAN DEBUG ==="] = "=== BANK-SCAN-DEBUG ==="
L["=== BANK QUALITY DEBUG ==="] = "=== BANK-QUALITÄTS-DEBUG ==="
L["Module enabled:"] = "Modul aktiviert:"
L["BankFrame exists:"] = "BankFrame vorhanden:"
L["BankFrame shown:"] = "BankFrame sichtbar:"
L["Usage: /dui shadowcolor red|green|reset|info"] = "Verwendung: /dui shadowcolor red|green|reset|info"
L["Usage: /dui shadowcrop <bottom_px> [right_px]"] = "Verwendung: /dui shadowcrop <bottom_px> [right_px]"
L["  e.g. /dui shadowcrop 90 - show top 90 of 128 px height"] = "  z. B. /dui shadowcrop 90 - zeigt die oberen 90 von 128 px"
L["  e.g. /dui shadowcrop 90 200 - crop both bottom and right"] = "  z. B. /dui shadowcrop 90 200 - unten und rechts beschneiden"
L["  /dui shadowcrop reset - restore full texture"] = "  /dui shadowcrop reset - vollständige Textur wiederherstellen"
L["BG reset to 256x128 full texture"] = "Hintergrund auf volle 256x128-Textur zurückgesetzt"
L["Crop applied: showing %dx%d of 256x128 (texcoord 0-%.3f, 0-%.3f)"] = "Zuschnitt aktiv: zeigt %dx%d von 256x128 (texcoord 0-%.3f, 0-%.3f)"
L["Invalid values. Height 1-128, Width 1-256"] = "Ungültige Werte. Höhe 1-128, Breite 1-256"
L["=== TargetFrame elements (use /dui shadowtest N to toggle) ==="] = "=== TargetFrame-Elemente (mit /dui shadowtest N umschalten) ==="
L["Total elements: %d"] = "Elemente insgesamt: %d"
L["HIDDEN: %d. %s [%s]"] = "VERSTECKT: %d. %s [%s]"
L["SHOWN: %d. %s [%s]"] = "SICHTBAR: %d. %s [%s]"
L["Invalid element number. Use /dui shadowtest to list."] = "Ungültige Elementnummer. /dui shadowtest listet sie auf."
L["DragonUI Compatibility:"] = "DragonUI-Kompatibilität:"
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
-- Item Level
L["Item Level"] = "Gegenstandsstufe"
L["Show item level on gear icons in bags, character panel, bank, and more"] = "Gegenstandsstufe auf Ausrüstungssymbolen in Taschen, Charakterfenster, Bank und mehr anzeigen"
L["Item Level: %d"] = "Gegenstandsstufe: %d"

L["Key Binding"] = "Tastenbelegung"
L["LibKeyBound integration for intuitive keybinding"] = "LibKeyBound-Integration für intuitive Tastenbelegung"
L["Buff Frame"] = "Buff-Rahmen"
L["Custom buff frame styling, positioning and toggle button"] = "Benutzerdefiniertes Styling, Positionierung und Umschaltknopf für den Buff-Rahmen"
L["Chat Mods"] = "Chat-Mods"
L["Chat enhancements: hide buttons, editbox position, URL copy, chat copy, link hover, tell target"] = "Chat-Verbesserungen: Buttons ausblenden, Eingabefeld-Position, URL-Kopie, Chat-Kopie, Link-Hover und Ziel anflüstern"
L["Bag Sort"] = "Taschensortierung"
L["Sort bags and bank items with buttons"] = "Taschen- und Bankgegenstände per Knopf sortieren"
L["Bag Skin"] = "Taschen-Design"
L["Retail-style skin for Blizzard bag windows"] = "Retail-Design für Blizzard-Taschenfenster"
L["Bagster"] = "Bagster"
L["All-in-one bag replacement with filtering and search"] = "All-in-One-Taschenersatz mit Filtern und Suche"
L["Stance Bar"] = "Haltungsleiste"
L["Vehicle"] = "Fahrzeug"
L["Vehicle interface enhancements"] = "Verbesserungen der Fahrzeugoberfläche"
L["Pet Bar"] = "Begleiterleiste"
L["Extra Bar"] = "Extra-Leiste"
L["A standalone action bar, independent of any class bonus bar"] = "Eine eigenständige Aktionsleiste, unabhängig von jeder Klassen-Bonusleiste"
L["Drag a spell, item or macro here."] = "Ziehe einen Zauber, Gegenstand oder ein Makro hierher."
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
L["|cff00ff00Left-Click|r to show this bag's items"] = "|cff00ff00Linksklick|r, um die Gegenstände dieser Tasche anzuzeigen"
L["|cff00ff00Left-Click|r to hide this bag's items"] = "|cff00ff00Linksklick|r, um die Gegenstände dieser Tasche auszublenden"
L["|cff00ff00Drag|r to move this bag"] = "|cff00ff00Ziehen|r, um diese Tasche zu verschieben"
L["Sort complete."] = "Sortierung abgeschlossen."
L["Sort already in progress."] = "Sortierung läuft bereits."
L["Bags already sorted!"] = "Taschen sind bereits sortiert!"
L["You must be at the bank."] = "Du musst an der Bank sein."
L["Bank already sorted!"] = "Bank ist bereits sortiert!"
L["Reputation: "] = "Ruf: "

L["Copy Text"] = "Text kopieren"

-- Version Check Module
L["Version Check"] = "Versionsprüfung"
L["Broadcast and detect addon version updates across group members"] = "Erkennt Addon-Updates zwischen Gruppenmitgliedern durch Senden und Empfangen der Version"

-- Quest nameplate icons wizard (Questie coexistence)
L["Quest Icons on Nameplates"] = "Questsymbole auf Namensplaketten"
L["Which quest icons do you want on your nameplates?"] = "Welche Questsymbole möchtest du auf deinen Namensplaketten?"
L["Kill"] = "Töten"
L["Loot"] = "Beute"
L['Pointer mode (just "!")'] = 'Zeigermodus (nur "!")'
L["Use Questie"] = "Questie verwenden"
L["Applying quest icon settings needs a UI reload."] = "Das Anwenden der Questsymbol-Einstellungen erfordert ein Neuladen der Oberfläche."
L["Reload"] = "Neu laden"

-- Alt Gold
L["Alt Gold"] = "Twink-Gold"
L["Show the gold of your other characters when hovering the money in your bags"] = "Zeigt das Gold deiner anderen Charaktere, wenn du über das Geld in deinen Taschen fährst"
L["Character Gold"] = "Gold der Charaktere"
L["No other characters recorded yet"] = "Noch keine weiteren Charaktere erfasst"
L["(current)"] = "(aktuell)"
L["Total"] = "Gesamt"

-- Added by DragonUI (missing translations)
L["Position editor not available."] = "Positionseditor ist nicht verfügbar."
L["Reset only supports resetting every position at once. Use /dragonui reset."] = "Zurücksetzen ist nur für alle Positionen gleichzeitig möglich. Verwende /dragonui reset."
L["Minimap Decorations"] = "Minikarten-Dekorationen"
L["Native animated minimap decoration effects for DragonUI."] = "Native animierte Dekorationseffekte für die DragonUI-Minikarte."
L["Click to sell all gray (poor) items to vendor."] = "Klicke, um alle grauen (schlechten) Gegenstände an den Händler zu verkaufen."
L["A merchant window must be open."] = "Ein Händlerfenster muss geöffnet sein."
L["Sold %d scrap item(s) for %s."] = "%d Schrottgegenstände für %s verkauft."
L["No scrap items to sell."] = "Keine Schrottgegenstände zum Verkaufen vorhanden."
L["Range Indicator"] = "Reichweitenanzeige"
L["Color action button icons when target is out of range or ability is unusable."] = "Färbt Aktionsschaltflächen ein, wenn das Ziel außer Reichweite oder die Fähigkeit nicht verwendbar ist."
L["Equipment"] = "Ausrüstung"
L["Usable"] = "Verwendbar"
L["Trade"] = "Handelswaren"
L["Target & Focus Aura Customization"] = "Anpassung der Auren von Ziel und Fokus"
L["Customize target/focus aura icons and timers."] = "Passe Aurensymbole und Zeitanzeigen von Ziel und Fokus an."
L["Aura Borders"] = "Aurenränder"
L["Modern borders on buff and debuff icons."] = "Moderne Ränder für Stärkungs- und Schwächungssymbole."
L["%s any bag slot (item or empty) to lock or unlock it."] = "%s auf einen beliebigen Taschenplatz (belegt oder leer), um ihn zu sperren oder freizugeben."
L["Left Click"] = "Linksklick"
L["Right Click"] = "Rechtsklick"
L["Middle Click"] = "Mittelklick"
L["%s's Inventory"] = "Inventar von %s"
L["%s's Bank"] = "Bank von %s"
L["Inventory"] = "Inventar"
L["Bags"] = "Taschen"
L["|cff00ff00Left-Click|r to toggle bag display"] = "|cff00ff00Linksklick|r zum Umschalten der Taschenanzeige"
L["|cff00ff00Right-Click|r to toggle inventory"] = "|cff00ff00Rechtsklick|r zum Umschalten des Inventars"
L["|cff00ff00Right-Click|r to toggle bank"] = "|cff00ff00Rechtsklick|r zum Umschalten der Bank"
L["|cff00ff00Drag|r to move"] = "|cff00ff00Ziehen|r zum Verschieben"
L["|cff00ff00Alt+Right-Click|r to reset position"] = "|cff00ff00Alt+Rechtsklick|r zum Zurücksetzen der Position"
L["Toggle Inventory"] = "Inventar umschalten"
L["Toggle Bank"] = "Bank umschalten"
L["Double-Click to Copy"] = "Doppelklick zum Kopieren"

-- Character Panel, Pets & Mounts and diagnostics
L["URL"] = "URL"
L["Normal"] = "Normal"
L["Unranked"] = "Kein Rang"
L["Alt"] = "Alt"
L["Ctrl"] = "Strg"
L["Shift"] = "Umschalt"
L["Character Panel"] = "Charakterfenster"
L["Retail-style character window with a modern frame, class portrait and stats sidebar"] = "Charakterfenster im Retail-Stil mit modernem Rahmen, Klassenporträt und Werteleiste"
L["Character Panel restored. Reload the UI for a fully clean state."] = "Charakterfenster zurückgesetzt. Lade die Oberfläche neu für einen ganz sauberen Zustand."
L["Pets & Mounts"] = "Haustiere & Reittiere"
L["The mounts and pets you have collected."] = "Die Reittiere und Haustiere, die Ihr gesammelt habt."
L["Dedicated window for your mounts and pets, opened from the micro menu"] = "Eigenes Fenster für Eure Reittiere und Haustiere, über das Mikromenü zu öffnen"
L["Pets & Mounts disabled. Reload the UI to remove its micro menu button."] = "Haustiere & Reittiere deaktiviert. Lade die Oberfläche neu, um die Mikromenü-Schaltfläche zu entfernen."
L["Favorite"] = "Favorit"
L["Remove Favorite"] = "Favorit entfernen"
L["Favorites"] = "Favoriten"
L["Keeps this at the front of the list."] = "Hält diesen Eintrag am Anfang der Liste."
L["Summon Random Favorite"] = "Zufälligen Favoriten rufen"
L["Mount Random Favorite"] = "Zufälligen Favoriten reiten"
L["Random Mount"] = "Zufallsreittier"
L["Random Pet"] = "Zufallshaustier"
L["Picks one random mount from your favorites."] = "Wählt zufällig ein Reittier aus Euren Favoriten."
L["Picks one random pet from your favorites."] = "Wählt zufällig einen Begleiter aus Euren Favoriten."
L["None of your favorites can be used here."] = "Keiner Eurer Favoriten lässt sich hier benutzen."
L["Mark some favorites first."] = "Markiert zuerst einen Favoriten."
L["Right-click for more options"] = "Rechtsklick für weitere Optionen"
L["Nothing collected yet."] = "Noch nichts gesammelt."
L["Not collected yet"] = "Noch nicht gesammelt"
L["Collected"] = "Gesammelt"
L["Not Collected"] = "Nicht gesammelt"
L["Drag to place it on an action bar."] = "Ziehen, um es auf eine Aktionsleiste zu legen."
L["No free macro slot for the random favorite button."] = "Kein freier Makroplatz für die Zufalls-Favoriten-Schaltfläche."
L["Unusable here"] = "Hier nicht nutzbar"
L["Ground"] = "Boden"
L["Flying"] = "Flug"
L["Aquatic"] = "Wasser"
L["Sources"] = "Quellen"
L["Source"] = "Quelle"
L["Check All"] = "Alle auswählen"
L["Uncheck All"] = "Alle abwählen"
L["Drop"] = "Beute"
L["Quest"] = "Quest"
L["Vendor"] = "Händler"
L["Profession"] = "Beruf"
L["Achievement"] = "Erfolg"
L["World Event"] = "Weltereignis"
L["Promotion"] = "Promotion"
L["Trading Card Game"] = "Sammelkartenspiel"
L["In-Game Shop"] = "Ingame-Shop"
L["Discovery"] = "Entdeckung"
L["/dragonui collections - Open the Pets & Mounts window"] = "/dragonui collections - Öffnet das Fenster Haustiere & Reittiere"
L["Average item level of your equipped gear."] = "Durchschnittliche Gegenstandsstufe deiner angelegten Ausrüstung."
L["Bank"] = "Bank"
L["Equip"] = "Anlegen"
L["New Equipment Set"] = "Neues Ausrüstungsset"
L["Rename or change the icon"] = "Umbenennen oder Symbol ändern"
L["Panel settings"] = "Fenstereinstellungen"
L["Background"] = "Hintergrund"
L["Stone"] = "Stein"
L["Dark"] = "Dunkel"
L["Model backdrop"] = "Modellhintergrund"
L["Greyscale"] = "Graustufen"
L["Full colour"] = "Volle Farbe"
L["You have not earned any titles yet."] = "Du hast noch keine Titel verdient."
L["This client can only re-save a set, so the gear you are wearing now replaces its contents."] = "Dieser Client kann ein Set nur neu speichern: die gerade getragene Ausrüstung ersetzt seinen Inhalt."
L["A set with that name already exists."] = "Ein Set mit diesem Namen existiert bereits."
L["Delete the equipment set '%s'?"] = "Ausrüstungsset '%s' löschen?"
L["Overwrite '%s' with your currently equipped items?"] = "'%s' mit der aktuell angelegten Ausrüstung überschreiben?"

-- Character Panel, Pets & Mounts and diagnostics
L["UFL diagnostic not available"] = "UFL-Diagnose nicht verfügbar"
L["(unnamed)"] = "(unbenannt)"
L["(unnamed_frame)"] = "(unbenannter_Frame)"
L["SHOWN"] = "SICHTBAR"
L["hidden"] = "versteckt"
L["VISIBLE"] = "SICHTBAR"
L["invisible"] = "unsichtbar"
L["VIS"] = "SICHT"
L["inv"] = "unsicht"
L["Rect: left=%.1f bottom=%.1f w=%.1f h=%.1f"] = "Rect: left=%.1f bottom=%.1f w=%.1f h=%.1f"
L["Point1: %s -> %s %s (%.1f, %.1f)"] = "Point1: %s -> %s %s (%.1f, %.1f)"
L["NumPoints: %d"] = "NumPoints: %d"
L["TexCoord: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f"] = "TexCoord: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f"

-- Character Panel, Pets & Mounts and diagnostics
L["CharacterFrame does not exist."] = "CharacterFrame existiert nicht."
L["Open the character panel first: sizes are meaningless while hidden."] = "Öffne zuerst das Charakterfenster: versteckt sind die Größen bedeutungslos."
L["(paperdoll-only rows below are skipped on this tab)"] = "(die reinen Paperdoll-Zeilen unten werden auf diesem Reiter übersprungen)"
L["Put the cursor on the 3D model, capturing in 5 seconds."] = "Zeiger auf das 3D-Modell setzen, Aufnahme in 5 Sekunden."
L["Ground dump failed: "] = "Hintergrund-Dump fehlgeschlagen: "
L["Model control dump failed: "] = "Dump der Modellsteuerung fehlgeschlagen: "

-- ============================================================================
-- PANELS TAB / GEAR SUMMARY
-- ============================================================================

L["Gear summary"] = "Ausrüstungsübersicht"
L["GearScore"] = "GearScore"
L["Weighted score of your equipped gear."] = "Gewichtete Wertung deiner angelegten Ausrüstung."
L["Reset stat order"] = "Reihenfolge zurücksetzen"
L["Restore the stat categories to their default order?"] = "Die Wertekategorien auf ihre Standardreihenfolge zurücksetzen?"
