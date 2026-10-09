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

local L = LibStub("AceLocale-3.0-DragonUI"):NewLocale("DragonUI", "enUS", true)
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
L["Position editor not available."] = true
L["Reset only supports resetting every position at once. Use /dragonui reset."] = true
L["Keybind mode not available."] = true
L["Vehicle debug not available"] = true
L["Unable to open configuration"] = true
L["Commands: /dragonui config, /dragonui edit"] = true
L["Minimap module restored to Blizzard defaults"] = true
L["Targeting: %s"] = true
L["XP: %d/%d"] = true
L["XP: "] = true
L["Remaining: "] = true
L["Rested: "] = true

-- Errors
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
L["Editable Frames: "] = true
L["DragonUI Version: "] = true

-- ============================================================================
-- EDITOR MODE
-- ============================================================================

L["Exit Edit Mode"] = true
L["Reset All Positions"] = true
L["Are you sure you want to reset all interface elements to their default positions?"] = true
L["Reset Position"] = true
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


-- ============================================================================
-- MINIMAP MODULE
-- ============================================================================

L["Minimap Decorations"] = true
L["Native animated minimap decoration effects for DragonUI."] = true
L["Minimap Buttons"] = true
L["Left-click to show or hide minimap addon buttons."] = "Left-Click to open minimap buttons."
L["Right-click to open DragonUI settings."] = true
L["Shift-click to open Editor Mode."] = true

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
L["DurabilityFrame"] = "Durability"
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
L["ExtraBar1"] = "Extra Bar"
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

-- Editor panel (Forever)
L["Editor Mode"] = true
L["Layout"] = true
L["Custom Layout"] = true
L["Show Grid"] = true
L["Save Layout"] = true
L["Delete Layout"] = true
L["Export Layout"] = true
L["Import Layout"] = true
L["Enter a name for the layout:"] = true
L["General"] = true

-- ============================================================================
-- COMPATIBILITY MODULE
-- ============================================================================

-- Conflict warning popup
L["DragonUI Conflict Warning"] = true
L["The addon |cFFFFFF00%s|r conflicts with DragonUI."] = true
L["Reason:"] = true
L["Disable the conflicting addon now?"] = true
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

-- Conflict reasons
L["Conflicts with DragonUI's custom unit frame textures and power bar system."] = true
L["Resets minimap mask and blip textures. DragonUI re-applies its custom textures automatically."] = true
L["SexyMap modifies the minimap borders, shape, and zone text which conflicts with DragonUI's minimap module."] = true
L["Reads native nameplate alpha to identify the target's plate; conflicts with DragonUI's default anti-dim behavior."] = true
L["Parents its cooldown icons to the native health bar; conflicts with DragonUI's default health-bar hiding."] = true

-- Nameplate addon compatibility popup
L["Detected |cFFFFFF00%s|r. Enable Nameplate Addon Compatibility so it works correctly?"] = true
L["Detected |cFFFFFF00%s|r. Enable Nameplate Health Bar Compatibility so it works correctly?"] = true
L["Enable"] = true

-- SexyMap compatibility popup
L["DragonUI - SexyMap Detected"] = true
L["Which minimap do you want to use?"] = true
L["SexyMap"] = true
L["DragonUI"] = true
L["Hybrid"] = true

-- SexyMap options panel
L["SexyMap Compatibility"] = true
L["Minimap Mode"] = true
L["Choose how DragonUI and SexyMap share the minimap."] = true
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
L["Not Now"] = true
L["Disable"] = true
L["Some interface settings are not configured optimally for DragonUI."] = true
L["This includes settings that conflict with DragonUI and settings recommended for the best visual experience."] = true
L["Affected settings:"] = true
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
L["Cooldown Text"] = true
L["Cooldown text on action buttons"] = true
L["Range Indicator"] = true
L["Color action button icons when target is out of range or ability is unusable."] = true
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
L["Item Level"] = true
L["Show item level on gear icons in bags, character panel, bank, and more"] = true
L["Item Level: %d"] = true
L["Unranked"] = true
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
L["Loot Window"] = true
L["Retail-style skin for the Blizzard loot window"] = true
L["Bagster"] = true
L["All-in-one bag replacement with filtering and search"] = true
L["Alt Gold"] = true
L["Show the gold of your other characters when hovering the money in your bags"] = true
-- Character Panel
L["Character Panel"] = true
L["Retail-style character window with a modern frame, class portrait and stats sidebar"] = true
L["Character Panel restored. Reload the UI for a fully clean state."] = true
L["CharacterFrame does not exist."] = true
L["Open the character panel first: sizes are meaningless while hidden."] = true
L["(paperdoll-only rows below are skipped on this tab)"] = true
L["Put the cursor on the 3D model, capturing in 5 seconds."] = true
L["Ground dump failed: "] = true
L["Model control dump failed: "] = true

-- Pets & Mounts
L["Pets & Mounts"] = true
L["The mounts and pets you have collected."] = true
L["Dedicated window for your mounts and pets, opened from the micro menu"] = true
L["Pets & Mounts disabled. Reload the UI to remove its micro menu button."] = true
L["Favorite"] = true
L["Remove Favorite"] = true
L["Favorites"] = true
L["Keeps this at the front of the list."] = true
L["Summon Random Favorite"] = true
L["Mount Random Favorite"] = true
L["Summon Random Favorite Mount"] = true
L["Summon Random Favorite Pet"] = true
L["Total Mounts"] = true
L["Total Pets"] = true
L["Hide maxed out"] = true
L["All"] = true
L["Hide empty"] = true
L["Hide inactive"] = true
L["Random Mount"] = true
L["Random Pet"] = true
L["Summons and dismisses a favorite mount that is usable in the current area."] = true
L["Summons and dismisses a favorite pet."] = true
L["If you don't have any favorite mounts, it'll choose from your whole collection."] = true
L["If you don't have any favorite pets, it'll choose from your whole collection."] = true
L["None of your favorites can be used here."] = true
L["Nothing you own can be used here."] = true
L["Right-click for more options"] = true
L["Nothing collected yet."] = true
L["No pet active"] = true
L["Not collected yet"] = true
L["Collected"] = true
L["Not Collected"] = true
L["Drag to place it on an action bar."] = true
L["No free macro slot for the random favorite button."] = true
L["Unusable here"] = true
L["Ground"] = true
L["Flying"] = true
L["Aquatic"] = true
L["Sources"] = true
L["Source"] = true
L["Check All"] = true
L["Uncheck All"] = true
L["Drop"] = true
L["Quest"] = true
L["Vendor"] = true
L["Profession"] = true
L["Achievement"] = true
L["World Event"] = true
L["Promotion"] = true
L["Trading Card Game"] = true
L["In-Game Shop"] = true
L["Discovery"] = true
L["/dragonui collections - Open the Pets & Mounts window"] = true
L["Average item level of your equipped gear."] = true
L["Character Gold"] = true
L["No other characters recorded yet"] = true
L["(current)"] = true
L["Total"] = true
L["Stance Bar"] = true
L["Vehicle"] = true
L["Vehicle interface enhancements"] = true
L["Pet Bar"] = true
L["Extra Bar"] = true
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
L["A standalone action bar, independent of any class bonus bar"] = true
L["Drag a spell, item or macro here."] = true
L["Micro menu and bags system styling and positioning"] = true
L["%s's Inventory"] = true
L["%s's Bank"] = true
L["Bags"] = true
L["|cff00ff00Left-Click|r to toggle bag display"] = true
L["|cff00ff00Right-Click|r to toggle inventory"] = true
L["|cff00ff00Right-Click|r to toggle bank"] = true
L["|cff00ff00Drag|r to move"] = true
L["|cff00ff00Alt+Right-Click|r to reset position"] = true
L["|cff00ff00Left-Click|r to show this bag's items"] = true
L["|cff00ff00Left-Click|r to hide this bag's items"] = true
L["|cff00ff00Drag|r to move this bag"] = true
L["Sort complete."] = true
L["Sort already in progress."] = true
L["Bags already sorted!"] = true
L["You must be at the bank."] = true
L["Bank already sorted!"] = true
L["Reputation: "] = true

L["Double-Click to Copy"] = true
L["Copy Text"] = true

-- Version Check Module
L["Version Check"] = true
L["Broadcast and detect addon version updates across group members"] = true

-- Quest nameplate icons wizard (Questie coexistence)
L["Quest Icons on Nameplates"] = true
L["Which quest icons do you want on your nameplates?"] = true
L["Kill"] = true
L["Loot"] = true
L['Pointer mode (just "!")'] = true
L["Use Questie"] = true
L["Applying quest icon settings needs a UI reload."] = true
L["Reload"] = true

-- ============================================================================
-- FRAME DIAGNOSTIC COMMANDS
-- ============================================================================

L["UFL diagnostic not available"] = true
L["(unnamed)"] = true
L["(unnamed_frame)"] = true
L["SHOWN"] = true
L["hidden"] = true
L["VISIBLE"] = true
L["invisible"] = true
L["VIS"] = true
L["inv"] = true
L["Rect: left=%.1f bottom=%.1f w=%.1f h=%.1f"] = true
L["Point1: %s -> %s %s (%.1f, %.1f)"] = true
L["NumPoints: %d"] = true
L["TexCoord: %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f, %.4f"] = true
-- Equipment manager pane
L["Equip"] = true
L["New Equipment Set"] = true
L["Rename or change the icon"] = true
L["Assign To:"] = true
L["Panel settings"] = true
L["Background"] = true
L["Stone"] = true
L["Dark"] = true
L["Model backdrop"] = true
L["Greyscale"] = true
L["Full colour"] = true
L["You have not earned any titles yet."] = true
L["This client can only re-save a set, so the gear you are wearing now replaces its contents."] = true
L["A set with that name already exists."] = true
L["Delete the equipment set '%s'?"] = true
L["Overwrite '%s' with your currently equipped items?"] = true
L["Equipment Manager is turned off."] = true
L["Equipment Manager is turned off. Enable it now?"] = true

-- ============================================================================
-- PANELS TAB / GEAR SUMMARY
-- ============================================================================

L["Gear summary"] = true
L["GearScore"] = true
L["Weighted score of your equipped gear."] = true
L["Reset stat order"] = true
L["Restore the stat categories to their default order?"] = true

--MERCHANT MODULE
L["Merchant"] = true
L["Retail-style vendor window chrome"] = true
L["Quest Dialog"] = true
L["Retail-style quest and gossip window chrome"] = true
L["Sell all junk items"] = true
L["You are about to sell all junk items and will not be able to buy them back.\n\nAre you sure you want to proceed?"] = true
L["Sold %d junk item(s)."] = true

-- World Map
L["World Map"] = true
L["Retail-style world map with breadcrumb navigation and a quest log side panel"] = true
L["Map & Quest Log"] = true
L["World"] = true
L["Maximize"] = true
L["Show Quest Log"] = true
L["Hide Quest Log"] = true
L["Show Landmarks"] = true
L["Show Undiscovered Areas"] = true
L["No quests on this map."] = true
L["Untrack"] = true
L["Abandon"] = true
L["Share"] = true
L["Show Dungeon Entrances"] = true
L["Show Graveyards"] = true
L["Graveyard"] = true
L["Show Flight Points"] = true
L["Flight Master"] = true
L["Show Inns"] = true
L["Hearthstone"] = true
L["Click to view on Map"] = true
L["Search Quest Log"] = true
L["World map module disabled: %s replaces the same map frame."] = true
L["Cursor"] = true
L["Show Zone Levels"] = true
L["Show Map Coordinates"] = true

-- Level Up Enhance Module
L["LevelUpFrame"] = "Level Up"
L["Level Up Enhance"] = true
L["Enhanced level-up notification with animated frame"] = true
L["You've Reached"] = true
L["Level %d"] = true

-- ============================================================================
-- LOW HP ALERT MODULE
-- ============================================================================

L["Low HP Alert"] = true
L["Plays a sound and flashes the screen edges when your HP drops below the threshold."] = true
L["Personal Resource Display"] = true
L["PersonalResource"] = true
L["Add Health and Resource below your Character."] = true
L["Swing Timer"] = true
L["Show a bar with the time left until each weapon's next swing."] = true
L["SwingTimerMainHand"] = "Main Hand Swing Timer"
L["SwingTimerOffHand"] = "Off Hand Swing Timer"
L["SwingTimerRanged"] = "Ranged Swing Timer"

-- Talents
L["Talents"] = true
L["Retail-style talent window"] = true
L["points available"] = true
L["Search talents"] = true
L["Rename specialization"] = true
L["Glyph options"] = true
L["Toggle slot name labels and the active-effects list."] = true
L["Show glyph names"] = true
L["Show glyph effects"] = true
L["NO ACTIVE EFFECTS"] = true
L["None active."] = true
L["Delete loadout '%s'? This cannot be undone."] = true
L["Rename this specialization (max %d characters):"] = true
L["Apply Changes"] = true
L["Save Build"] = true
L["Undo the last point"] = true
L["Exit Editor"] = true
L["Back to your live talents. Saved builds keep every change."] = true
L["Talent Builds"] = true
L["Design and save builds offline — no points needed."] = true
L["New build"] = true
L["New build from current talents"] = true
L["Copy code"] = true
L["Post link in chat"] = true
L["Asking %s for the build…"] = true
L["%s didn't answer — they may be offline or not running DragonUI."] = true
L["Import code…"] = true
L["Load onto character"] = true
L["Edit"] = true
L["Rename"] = true
L["Editing: %s"] = true
L["Level Required: %d"] = true
L["(auto)"] = true
L["%d / %d points · Level %d"] = true
L["In this build: rank %d / %d"] = true
L["Not in this build"] = true
L["You have unsaved changes in '%s'. Save them?"] = true
L["Discard"] = true
L["This build conflicts with talents you've already spent.\n\nVisit your class trainer to reset your talents, then load the build again."] = true
L["Character already matches this build."] = true
L["This build needs %d points; you have %d unspent."] = true
L["Build staged — click Apply Changes to learn it."] = true
L["Only %d of %d points could be staged — check the trees before applying."] = true
L["Name this build:"] = true
L["Level required for this build (10-%d).\nLeave blank for automatic (grows with the build)."] = true
L["Level clamped to %d (build size / level cap)."] = true
L["Paste a DragonUI talent code:"] = true
L["Talent import: %s"] = true
L["Talent build code (Ctrl+C to copy):"] = true
L["Build saved: %s"] = true
L["Build saved for %s: %s"] = true
L["Build sent (%s). Only DragonUI players will see it."] = true
L["%s shared a talent build with you:"] = true
L["Imported"] = true
L["couldn't read a talent code"] = true
L["talent data unavailable"] = true
L["that build doesn't fit your talent trees"] = true
L["Import to My Profiles"] = true
L["Save this build to your talent profiles."] = true
L["Enabled — click to toggle"] = true
L["Disabled — click to toggle"] = true
L["Glyph of "] = true

-- ============================================================================
-- SPELLBOOK MODULE
-- ============================================================================

L["Spellbook"] = true
L["Learned spells book with categories, search, and filters."] = true
L["Spellbook settings"] = true
L["Show All Ranks"] = true
L["Hide Passives"] = true
L["Training Cost"] = true
L["Show second page"] = true
L["Show single page"] = true
L["Page %d/%d"] = true
L["No spells match your search"] = true
L["Rank %d at trainer"] = "(Rank %d at trainer)"
L["Ranks %d-%d at trainer"] = "(Ranks %d-%d at trainer)"
L["Available from your class trainer"] = true
L["Highlight spells missing from action bars"] = true
L["Trainable"] = true
L["Available at level %d"] = true
L["Requires talent"] = true
L["Hide Unlearned Spells"] = true
L["Show Lower Rank Selector"] = true
L["Menu under the icon"] = true
L["Side flyout"] = true
L["Lower Ranks"] = true

-- Dropdown placeholder
L["Click to select"] = true

-- ============================================================================
-- EDITOR SETTINGS (per-frame dialog of the editor)
-- ============================================================================

-- Editor settings
L["AND (both required)"] = true
L["OR (either condition)"] = true
L["Visibility"] = true
L["Always Hidden"] = true
L["Show on Hover Only"] = true
L["Show in Combat Only"] = true
L["Hide in Combat"] = true
L["Hover/Combat Logic"] = true
L["Current Value"] = true
L["Percentage"] = true
L["Numbers + %"] = true
L["Current / Max"] = true
L["Auto"] = true
L["Forever"] = true
L["Text Format"] = true
L["Format Large Numbers"] = true
L["Always Show Health Text"] = true
L["Always Show Mana Text"] = true
L["Level Style"] = true
L["Class Portrait"] = true
L["Alternative Class Icons"] = true
L["Show PvP Icon"] = true
L["PvP Icon Style"] = true
L["Scale"] = true
L["Fat Health Bar"] = true
L["Hide Mana Bar"] = true
L["Dragon Decoration"] = true
L["None"] = true
L["Elite (Retail)"] = true
L["RareElite (Retail)"] = true
L["Elite (Forever)"] = true
L["RareElite (Forever)"] = true
L["World Boss (Forever)"] = true
L["Class Color Health"] = true
L["Text Display"] = true
L["Appearance"] = true
L["Glow Effects"] = true
L["Show Rest Glow"] = true
L["Show Combat Flash"] = true
L["Combat Flash Opacity"] = true
L["Alternate Mana (Druid)"] = true
L["Always Show"] = true
L["Percentage + Current/Max"] = true
L["Mana Bar Width"] = true
L["Mana Bar Height"] = true
L["Mana Bar Texture"] = true
L["DragonUI (Default)"] = true
L["Blizzard Classic"] = true
L["Flat Solid"] = true
L["Smooth"] = true
L["Aluminium"] = true
L["LiteStep"] = true
L["Show Buffs"] = true
L["Show Debuffs"] = true
L["Show Name Background"] = true
L["Show Buff/Debuff on Focus"] = true
L["X Position"] = true
L["Y Position"] = true
L["Threat Glow"] = true
L["Orientation"] = true
L["Vertical"] = true
L["Horizontal"] = true
L["Vertical Padding"] = true
L["Horizontal Padding"] = true
L["Width"] = true
L["Height"] = true
L["Show Icon"] = true
L["Icon Size"] = true
L["Modern Icon Border"] = true
L["Text Mode"] = true
L["Simple (Name Only)"] = true
L["Detailed (Name + Time)"] = true
L["Time Precision"] = true
L["Max Time Precision"] = true
L["Behavior"] = true
L["Hold Time (Success)"] = true
L["Hold Time (Interrupt)"] = true
L["Latency Indicator"] = true
L["Enable Latency Indicator"] = true
L["Latency Alpha"] = true
L["Top Left"] = true
L["Bottom Left"] = true
L["Top Right"] = true
L["Bottom Right"] = true
L["Columns"] = true
L["Buttons Shown"] = true
L["Button Spacing"] = true
L["Change Button Order"] = true
L["Button Order"] = true
L["Gryphons"] = true
L["Style"] = true
L["Classic"] = true
L["Dragonflight"] = true
L["Hidden"] = true
L["Gryphon Scale"] = true
L["Gryphon Offset X"] = true
L["Gryphon Offset Y"] = true
L["Size & Scale"] = true
L["Bar Width"] = true
L["Bar Height"] = true
L["Rested XP"] = true
L["Show Rested XP Background"] = true
L["Show Exhaustion Tick"] = true
L["Always Show Text"] = true
L["Show XP Percentage"] = true
L["XP / Rep Bar Style"] = true
L["DragonflightUI"] = true
L["RetailUI"] = true
L["Experience Bar Scale"] = true
L["Reputation Bar Scale"] = true
L["Grayscale Icons"] = true
L["Icon Spacing"] = true
L["Invert Button Order"] = true
L["Hide on Vehicle"] = true
L["Show Latency Indicator"] = true
L["Enable Bagster"] = true
L["Button Size"] = true
L["Show Empty Slots"] = true
L["Text Visibility"] = true
L["Show Hotkey Text"] = true
L["Minimap Buttons Collector"] = true
L["Circle"] = true
L["Arrow"] = true
L["Addon Button Skin"] = true
L["Addon Button Fade"] = true
L["Basic Settings"] = true
L["Border Alpha"] = true
L["New Blip Style"] = true
L["Player Arrow Size"] = true
L["Time & Calendar"] = true
L["Show Clock"] = true
L["Clock Font Size"] = true
L["Show Calendar"] = true
L["Display Settings"] = true
L["Tracking Icons"] = true
L["Zoom Buttons"] = true
L["Zone Text Font Size"] = true
L["Enable Minimap Decorations"] = true
L["Preset"] = true
L["Animated Effects"] = true
L["Hide DragonUI Border"] = true
L["Opacity"] = true
L["Separate Weapon Enchants"] = true
L["Show Aura Spell ID"] = true
L["Buff Icon Scale"] = true
L["Buffs Per Row"] = true
L["Max Buff Rows"] = true
L["Buff Horizontal Gap"] = true
L["Buff Vertical Gap"] = true
L["Buff Order"] = true
L["Default (Blizzard)"] = true
L["Player Buffs First"] = true
L["Other Player Buffs First"] = true
L["Duration Buffs First"] = true
L["Show Toggle Button"] = true
L["Layout Preview"] = true
L["Enable Layout Preview"] = true
L["Preview Buff Count"] = true
L["Enable Aura Borders"] = true
L["Border Style"] = true
L["Detailed"] = true
L["Rounded"] = true
L["Square"] = true
L["Aura Tooltips"] = true
L["Debuff Icon Scale"] = true
L["Debuffs Per Row"] = true
L["Max Debuff Rows"] = true
L["Debuff Horizontal Gap"] = true
L["Debuff Vertical Gap"] = true
L["Debuff Attached Offset Y"] = true
L["Preview Debuff Count"] = true
L["Anchor to Cursor"] = true
L["Class-Colored Border"] = true
L["Class-Colored Name"] = true
L["Target of Target"] = true
L["Styled Health Bar"] = true
L["Show Aura Source"] = true
L["Show Header Background"] = true
L["Font Size"] = true
L["Custom Height"] = true
L["Size"] = true
L["Narrow"] = true
L["Wide"] = true
L["Health Bar Height"] = true
L["Short"] = true
L["Tall"] = true
L["Power Bar Height"] = true
L["Padding"] = true
L["Always"] = true
L["In Combat"] = true
L["Hide Health Bar"] = true
L["Hide Power Bar"] = true
L["Hide Alternate Power Bar"] = true
L["Show Class Color"] = true
L["Show Bar Text"] = true
L["Show Bar Title"] = true
L["Show Time"] = true
L["Color"] = true
L["Enable Dark Mode"] = true
L["Intensity"] = true
L["Light (subtle)"] = true
L["Medium (balanced)"] = true
L["Dark (maximum)"] = true
L["Custom Color"] = true
L["Unit Frame Appearance"] = true
L["Unit Frame Art"] = true
L["Elite Dragons"] = true
L["Elite Dragons (Target)"] = true
L["Center Names"] = true
L["Combat"] = true
L["Action Bars"] = true
L["Bottom Left Bar"] = true
L["Bottom Right Bar"] = true
L["Right Bar"] = true
L["Left Bar"] = true
L["A 12-button action bar independent of every class's bonus bar (stance/stealth/vehicle)."] = true
L["Button Appearance"] = true
L["Main Bar Only Background"] = true
L["Hide Main Bar Background"] = true
L["Button Tooltips"] = true
L["Never"] = true
L["Show Count Text"] = true
L["Show Macro Names"] = true
L["Hotkey Font Size"] = true
L["Show Cooldown Text"] = true
L["Min Duration"] = true
L["Whole Seconds"] = true
L["Show cooldown text in whole seconds, without the tenths under 5 seconds."] = true

-- Addon Manager
L["Addon Manager"] = true
L["Enable and disable your addons in game from an AddOns button in the Esc menu"] = true
L["Load out of date AddOns"] = true
L["Search..."] = true
L["Addon Memory:"] = true
L["Enable All"] = true
L["Disable All"] = true
L["OK / Reload"] = true
L["Parent Disabled"] = true
L["Protected"] = true
L["Turn it back on from the AddOns button in the Esc menu."] = true
L["Turn it back on from the AddOns list at character selection."] = true
