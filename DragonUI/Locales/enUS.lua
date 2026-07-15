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

local L = LibStub("AceLocale-3.0"):NewLocale("DragonUI", "enUS", true)
if not L then return end

-- ============================================================================
-- CORE / GENERAL
-- ============================================================================

-- Combat lockdown messages
L["Cannot toggle editor mode during combat!"] = true
L["Cannot reset positions during combat!"] = true
L["Cannot toggle keybind mode during combat!"] = true
L["Cannot move frames during combat!"] = true
L["Cannot open options in combat."] = true
L["Options panel not available. Try /reload."] = true

-- Module availability
L["Editor mode not available."] = true
L["Keybind mode not available."] = true
L["Vehicle debug not available"] = true
L["KeyBinding module not available"] = true
L["Unable to open configuration"] = true
L["Commands: /dragonui config, /dragonui edit"] = true
L["Reset position: %s"] = true
L["All positions reset to defaults"] = true
L["Editor mode enabled - Drag frames to reposition"] = true
L["Editor mode disabled - Positions saved"] = true
L["Minimap module restored to Blizzard defaults"] = true
L["All action bar scales reset to default values"] = true
L["Minimap position reset to default"] = true
L["Targeting: %s"] = true
L["XP: %d/%d"] = true
L["GROUP %d"] = true
L["XP: "] = true
L["Remaining: "] = true
L["Rested: "] = true

-- Errors
L["Error executing pending operation:"] = true
L["Error -- Addon 'DragonUI_Options' not found or is disabled."] = true

-- ============================================================================
-- SLASH COMMANDS / HELP
-- ============================================================================

L["Unknown command: "] = true
L["=== DragonUI Commands ==="] = true
L["/dragonui or /dui - Open configuration"] = true
L["/dragonui config - Open configuration"] = true
L["/dragonui edit - Toggle editor mode (move UI elements)"] = true
L["/dragonui reset - Reset all positions to defaults"] = true
L["/dragonui reset <name> - Reset specific mover"] = true
L["/dragonui status - Show module status"] = true
L["/dragonui kb - Toggle keybind mode"] = true
L["/dragonui version - Show version info"] = true
L["/dragonui help - Show this help"] = true
L["/rl - Reload UI"] = true

-- ============================================================================
-- STATUS DISPLAY
-- ============================================================================

L["=== DragonUI Status ==="] = true
L["Detected Modules:"] = true
L["Loaded"] = true
L["Not Loaded"] = true
L["Target Frame"] = true
L["Focus Frame"] = true
L["Party Frames"] = true
L["Cooldowns"] = true
L["Registered Movers: "] = true
L["Editable Frames: "] = true
L["DragonUI Version: "] = true
L["Use /dragonui edit to enter edit mode, then right-click frames to reset."] = true

-- ============================================================================
-- EDITOR MODE
-- ============================================================================

L["Exit Edit Mode"] = true
L["Reset All Positions"] = true
L["Are you sure you want to reset all interface elements to their default positions?"] = true
L["Yes"] = true
L["No"] = true
L["UI elements have been repositioned. Reload UI to ensure all graphics display correctly?"] = true
L["Reload Now"] = true
L["Later"] = true

-- Position presets (edit mode)
L["Position Presets"] = true
L["Position Preset"] = true
L["Save"] = true
L["Import"] = true
L["Cancel"] = true
L["Load"] = true
L["Delete"] = true
L["Select All"] = true
L["Click to load"] = true
L["No position presets saved yet."] = true
L["Load position preset '%s'? This will overwrite your current element positions."] = true
L["Delete position preset '%s'? This cannot be undone."] = true
L["Enter a name for the imported position preset:"] = true
L["Imported Position Preset"] = true
L["Position preset saved: "] = true
L["Position preset loaded: "] = true
L["Position preset deleted: "] = true
L["Position preset imported: "] = true
L["Export Position Preset"] = true
L["Import Position Preset"] = true
L["Invalid position preset string."] = true
L["Not a valid DragonUI position preset string."] = true
L["Failed to export position preset."] = true
L["Save New Preset"] = true
L["Load Preset"] = true
L["Delete Preset"] = true
L["Export Preset"] = true
L["Import Preset"] = true

-- ============================================================================
-- KEYBINDING MODULE
-- ============================================================================

L["LibKeyBound-1.0 not found or failed to load:"] = true
L["Commands:"] = true
L["/dukb - Toggle keybinding mode"] = true
L["/dukb help - Show this help"] = true
L["Module disabled."] = true
L["Keybinding mode activated. Hover over buttons and press keys to bind them."] = true
L["Keybinding mode deactivated."] = true

-- ============================================================================
-- GAME MENU
-- ============================================================================

L["DragonUI"] = true

-- ============================================================================
-- MINIMAP MODULE
-- ============================================================================

L["DragonUI: Minimap module restored to Blizzard defaults"] = true
L["Minimap Decorations"] = true
L["Native animated minimap decoration effects for DragonUI."] = true
L["Minimap Buttons"] = true
L["Minimap Buttons Collector"] = "Minimap Buttons"
L["Left-click to show or hide minimap addon buttons."] = "Left-Click to open minimap buttons."
L["Right-click to open DragonUI settings."] = true

-- ============================================================================
-- EDITOR MODE LABELS (displayed on mover overlays)
-- ============================================================================

L["MainBar"] = "Main Bar"
L["RightBar"] = "Right Bar"
L["LeftBar"] = "Left Bar"
L["BottomBarLeft"] = "Bottom Left"
L["BottomBarRight"] = "Bottom Right"
L["XPBar"] = "XP Bar"
L["RepBar"] = "Rep Bar"
L["MinimapFrame"] = "Minimap"
L["LFGFrame"] = "Dungeon Eye"
L["PlayerFrame"] = "Player"
L["ManaBar"] = "Mana Bar"
L["PetFrame"] = "Pet"
L["ToT"] = "ToT"
L["ToF"] = "ToF"
L["tot"] = "ToT"
L["fot"] = "FoT"
L["PartyFrames"] = "Party"
L["TargetFrame"] = "Target"
L["FocusFrame"] = "Focus"
L["BagsBar"] = "Bags"
L["MicroMenu"] = "Micro Menu"
L["VehicleExitOverlay"] = "Vehicle Exit"
L["StanceOverlay"] = "Stance Bar"
L["petbar"] = "Pet Bar"
L["boss"] = "Boss Frames"
L["Boss Frames"] = true
L["Boss1Frame"] = "Boss Frames"
L["Boss2Frame"] = "Boss Frames"
L["Boss3Frame"] = "Boss Frames"
L["Boss4Frame"] = "Boss Frames"
L["TotemBarOverlay"] = "Totem Bar"
L["PlayerCastbar"] = "Castbar"
L["TargetCastbar"] = "Target Castbar"
L["FocusCastbar"] = "Focus Castbar"
L["TooltipWidget"] = "Tooltip"
L["Buff"] = true
L["Debuffs"] = "Debuff"
L["WeaponEnchants"] = "Weapon Enchants"
L["Loot Roll"] = true
L["Quest Tracker"] = true

-- Mover tooltip strings
L["Drag to move"] = true
L["Animated minimap border effects for DragonUI."] = true
L["Right-click to reset"] = true
L["Click to reset"] = true
L["Status Tooltip:"] = true
L["Top"] = true
L["Bottom"] = true
L["Left"] = true
L["Right"] = true
L["Error Messages"] = true
L["ErrorMessages"] = true

-- Editor mode system messages
L["All editable frames shown for editing"] = true
L["All editable frames hidden, positions saved"] = true

-- ============================================================================
-- COMPATIBILITY MODULE
-- ============================================================================

-- Conflict warning popup
L["DragonUI Conflict Warning"] = true
L["The addon |cFFFFFF00%s|r conflicts with DragonUI."] = true
L["Reason:"] = true
L["Disable the conflicting addon now?"] = true
L["Disable"] = true
L["Keep Both"] = true
L["DragonUI - D3D9Ex Warning"] = true
L["DragonUI detected that your client is using D3D9Ex."] = true
L["DragonUI's action bar system is not compatible with D3D9Ex."] = true
L["Some DragonUI action bar textures will be missing while this mode is active."] = true
L["If you want to disable this mode, open WTF\\Config.wtf."] = true
L["Delete this line:"] = true
L["Or replace it with:"] = true
L["Hide Gryphons"] = true
L["Understood"] = true
L["DragonUI - UnitFrameLayers Detected"] = true
L["DragonUI already includes Unit Frame Layers functionality (heal prediction, absorb shields, and animated health loss)."] = true
L["Choose how to resolve this overlap:"] = true
L["Use DragonUI: disable external UnitFrameLayers and enable DragonUI layers."] = true
L["Disable Both: disable external UnitFrameLayers and keep DragonUI layers disabled."] = true
L["Use DragonUI"] = true
L["Disable Both"] = true
L["Use DragonUI Unit Frame Layers"] = true
L["Disable both Unit Frame Layers"] = true
L["DragonUI - Party Frame Issue"] = true
L["You joined a party while in combat. Due to CompactRaidFrame taint issues, party frames may not display correctly."] = true
L["Reload the UI to fix party frame display?"] = true

-- Conflict reasons
L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = true
L["Known taint issues when manipulating party frames during combat. DragonUI provides automatic fixes."] = true
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = true
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = true
L["Reads native nameplate alpha to identify the target's plate; conflicts with DragonUI's default anti-dim behavior."] = true

-- Nameplate addon compatibility popup
L["Detected |cFFFFFF00%s|r. Enable Nameplate Addon Compatibility so it works correctly?"] = true
L["Enable"] = true

-- SexyMap compatibility popup
L["DragonUI - SexyMap Detected"] = true
L["Which minimap do you want to use?"] = true
L["SexyMap"] = true
L["DragonUI"] = true
L["Hybrid"] = true
L["Recommended"] = true

-- SexyMap options panel
L["SexyMap Compatibility"] = true
L["Minimap Mode"] = true
L["Choose how DragonUI and SexyMap share the minimap."] = true
L["Requires UI reload to apply."] = true
L["Uses SexyMap for the minimap."] = true
L["Uses DragonUI for the minimap."] = true
L["SexyMap visuals with DragonUI editor and positioning."] = "SexyMap look, moveable and configurable from DragonUI."
L["Minimap mode changed. Reload UI to apply?"] = true

-- SexyMap slash commands
L["SexyMap compatibility mode has been reset. Reload UI to choose again."] = true
L["Current SexyMap mode: |cFFFFFF00%s|r"] = true
L["No SexyMap mode selected (SexyMap not detected or not yet chosen)."] = true
L["Show current SexyMap compatibility mode"] = true
L["Reset SexyMap mode choice (re-prompts on reload)"] = true
L["Loaded addons:"] = true

-- ============================================================================
-- STATIC POPUPS (shared between modules)
-- ============================================================================

L["Changing this setting requires a UI reload to apply correctly."] = true
L["URL"] = true
L["Reload UI"] = true
L["Not Now"] = true
L["Disable"] = true
L["Ignore"] = true
L["Skip"] = true
L["The Blizzard option |cFFFFFF00Party/Arena Background|r is enabled. This conflicts with DragonUI's party frames."] = true
L["Disable it now?"] = true
L["Some interface settings are not configured optimally for DragonUI."] = true
L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] = true
L["Affected settings:"] = true
L["Some interface settings are not configured optimally for DragonUI. Do you want to fix them?"] = true
L["Do you want to fix them now?"] = true
L["Party/Arena Background"] = true
L["Default Status Text"] = true
L["Conflict"] = true
L["Recommended"] = true

-- Bag Sort
L["Sort Bags"] = true
L["Sort Bank"] = true
L["Sort Items"] = true
L["Click to sort items by type, rarity, and name."] = true
L["Clear Locked Slots"] = true
L["Click to clear all locked bag slots."] = true
L["Alt+LeftClick any bag slot (item or empty) to lock or unlock it."] = true
L["Click the lock-clear button to remove all locked slots."] = true
L["Hover an item or slot, then type /sortlock."] = true
L["Slot locked (bag %d, slot %d)."] = true
L["Slot unlocked (bag %d, slot %d)."] = true
L["Could not clear locks (config not ready)."] = true
L["Cleared all sort-locked slots."] = true

-- Sell Scrap
L["Sell Scrap"] = true
L["Click to sell all gray (poor) items to vendor."] = true
L["A merchant window must be open."] = true
L["Open a merchant window first to sell scrap items."] = true
L["Sold %d scrap item(s) for %s."] = true
L["No scrap items to sell."] = true

-- Guild Bank Sort
L["You must be at the guild bank."] = true
L["Could not determine the current guild bank tab."] = true
L["You need full deposit and withdraw access to this tab to sort it."] = true
L["This guild bank tab is already sorted!"] = true
L["Sort this guild bank tab? Depending on your server, this may be logged and count against your guild's shared withdrawal allowance, the same as moving items by hand."] = true
L["Sort"] = true
L["Click to sort items in the currently open guild bank tab."] = true
L["Never moves items between tabs."] = true
L["Sort Guild Bank Tab"] = true

-- Micromenu Latency
L["Network"] = true
L["Latency"] = true

-- ============================================================================
-- STABILIZATION PATCH STRINGS
-- ============================================================================

L["/dragonui debug on|off|status - Toggle diagnostic logging"] = true
L["Usage: /dragonui debug on|off|status"] = true
L["Enable debug mode first with /dragonui debug on"] = true
L["Debug mode is %s"] = true
L["Debug mode enabled"] = true
L["Debug mode disabled"] = true
L["enabled"] = true
L["disabled"] = true
L["Enabled"] = true
L["Disabled"] = true
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
L["Registered Modules:"] = true
L["No modules registered in ModuleRegistry"] = true
L["load-once"] = true
L["%s will disable after /reload because its secure hooks cannot be removed safely."] = true
L["%s uses permanent secure hooks and will fully disable after /reload."] = true
L["%s remains active until /reload because its secure hooks cannot be removed safely."] = true
L["Cooldown Text"] = true
L["Cooldown text on action buttons"] = true
L["Cast Bar"] = true
L["Custom player, target, and focus cast bars"] = true
L["Multicast"] = true
L["Shaman totem bar positioning and styling"] = true
L["Player Frame"] = true
L["Dragonflight-styled boss target frames"] = true
L["Dragonflight-styled player unit frame"] = true
L["ModuleRegistry:Register requires name and moduleTable"] = true
L["ModuleRegistry: Module already registered -"] = true
L["ModuleRegistry: Registered module -"] = true
L["order:"] = true
L["ModuleRegistry: Refresh failed for"] = true
L["ModuleRegistry: Unknown module -"] = true
L["ModuleRegistry: Enabled -"] = true
L["ModuleRegistry: Disabled -"] = true
L["CombatQueue:Add requires id and func"] = true
L["CombatQueue: Registered PLAYER_REGEN_ENABLED"] = true
L["CombatQueue: Queued operation -"] = true
L["CombatQueue: Removed operation -"] = true
L["CombatQueue: Processing"] = true
L["queued operations"] = true
L["CombatQueue: Failed to execute"] = true
L["CombatQueue: Executed -"] = true
L["CombatQueue: Unregistered PLAYER_REGEN_ENABLED"] = true
L["CombatQueue: Immediate execution failed -"] = true

-- ============================================================================
-- RELEASE PREP STRINGS
-- ============================================================================

L["Buttons"] = true
L["Action button styling and enhancements"] = true
L["Equipment"] = true
L["Usable"] = true
L["Normal"] = true
L["Trade"] = true
L["Target & Focus Aura Customization"] = true
L["Customize target/focus aura icons and timers."] = true
L["Aura Borders"] = true
L["Modern borders on buff and debuff icons."] = true
L["Dark Mode"] = true
L["Darken UI borders and chrome"] = true
L["Item Quality"] = true
L["Color item borders by quality in bags, character panel, bank, and merchant"] = true
L["Key Binding"] = true
L["LibKeyBound integration for intuitive keybinding"] = true
L["Buff Frame"] = true
L["Custom buff frame styling, positioning and toggle button"] = true
L["Chat Mods"] = true
L["Chat enhancements: hide buttons, editbox position, URL copy, chat copy, link hover, tell target"] = true
L["Bag Sort"] = true
L["Sort bags and bank items with buttons"] = true
L["%s any bag slot (item or empty) to lock or unlock it."] = true
L["Alt"] = true
L["Ctrl"] = true
L["Shift"] = true
L["Left Click"] = true
L["Right Click"] = true
L["Middle Click"] = true
L["Bag Skin"] = true
L["Retail-style skin for Blizzard bag windows"] = true
L["Combuctor"] = true
L["All-in-one bag replacement with filtering and search"] = true
L["Stance Bar"] = true
L["Vehicle"] = true
L["Vehicle interface enhancements"] = true
L["Pet Bar"] = true
L["Micro Menu"] = true
L["Main Bars"] = true
L["Main action bars, status bars, scaling and positioning"] = true
L["Hide Blizzard"] = true
L["Hide default Blizzard UI elements"] = true
L["Minimap"] = true
L["Custom minimap styling, positioning, tracking icons and calendar"] = true
L["Quest tracker positioning and styling"] = true
L["Tooltip"] = true
L["Enhanced tooltip styling with class colors and health bars"] = true
L["Nameplates"] = true
L["Apply DragonUI nameplate styling."] = true
L["Unit Frame Layers"] = true
L["Heal prediction, absorb shields, and animated health loss on unit frames"] = true
L["Stance/shapeshift bar positioning and styling"] = true
L["Pet action bar positioning and styling"] = true
L["Micro menu and bags system styling and positioning"] = true
L["%s's Inventory"] = true
L["%s's Bank"] = true
L["Inventory"] = true
L["Bank"] = true
L["Bags"] = true
L["|cff00ff00Left-Click|r to toggle bag display"] = true
L["|cff00ff00Right-Click|r to toggle inventory"] = true
L["|cff00ff00Right-Click|r to toggle bank"] = true
L["|cff00ff00Drag|r to move"] = true
L["|cff00ff00Alt+Right-Click|r to reset position"] = true
L["Toggle Inventory"] = true
L["Toggle Bank"] = true
L["Sort complete."] = true
L["Sort already in progress."] = true
L["Bags already sorted!"] = true
L["You must be at the bank."] = true
L["Bank already sorted!"] = true
L["Reputation: "] = true
L["Error in SafeCall:"] = true

L["Double-Click to Copy"] = true
L["Copy Text"] = true

-- Version Check Module
L["Version Check"] = true
L["Broadcast and detect addon version updates across group members"] = true
