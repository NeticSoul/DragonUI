--[[
================================================================================
DragonUI_Options - English Locale (Default)
================================================================================
Base locale for the options panel: labels, descriptions, section headers,
dropdown values, print messages, popup text.

When adding new strings:
1. Add L[<your key>] = true here
2. Use L["Your String"] in your options code
3. Add translations to other locale files
================================================================================
]]

local L = LibStub("AceLocale-3.0-DragonUI"):NewLocale("DragonUI_Options", "enUS", true)
if not L then return end

-- ============================================================================
-- GENERAL / PANEL
-- ============================================================================

L["DragonUI"] = true
L["Use the tabs on the left to configure modules, action bars, unit frames, minimap, and more."] = true
L["Editor Mode"] = true
L["Cannot open options during combat."] = true
L["Open DragonUI Settings"] = true
L["Open the DragonUI configuration panel."] = true
L["Use /dragonui to open the full settings panel."] = true

-- Quick Actions
L["Quick Actions"] = true
L["Jump to popular settings sections."] = true
L["Action Bar Layout"] = true
L["Configure dark tinting for all UI chrome."] = true
L["Full-width health bar that fills the entire player frame."] = true
L["Add a decorative dragon to your player frame."] = true
L["Heal prediction, absorb shields and animated health loss."] = true
L["Change columns, rows, and buttons shown per action bar."] = true
L["Switch micro menu icons between colored and grayscale style."] = true
L["About"] = true
L["Bringing the retail WoW look to 3.3.5a, inspired by Dragonflight UI."] = true
L["Created and maintained by NeticSoul, with community contributions."] = true

-- Language
L["Language"] = true
L["Choose the language used by the DragonUI interface."] = true
L["Follow the client language"] = true

L["Commands: /dragonui, /dui, /pi \226\128\148 /dragonui edit (editor) \226\128\148 /dragonui help"] = true
L["GitHub (select and Ctrl+C to copy):"] = true
L["All"] = true
L["Error:"] = true
L["Error: DragonUI addon not found!"] = true

-- ============================================================================
-- STATIC POPUPS
-- ============================================================================

L["Changing this setting requires a UI reload to apply correctly."] = true
L["Reload UI"] = true
L["Not Now"] = true
L["Reload Now"] = true
L["Cancel"] = true
L["Yes"] = true
L["No"] = true

-- ============================================================================
-- TAB NAMES
-- ============================================================================

L["General"] = true
L["Modules"] = true
L["Action Bars"] = true
L["Additional Bars"] = true
L["Minimap"] = true
L["Profiles"] = true
L["Unit Frames"] = true
L["XP & Rep Bars"] = true
L["Chat"] = true
L["Appearance"] = true

-- ============================================================================
-- MODULES TAB
-- ============================================================================

-- Headers & descriptions
L["Toggle individual modules on or off. Disabled modules revert to the default Blizzard UI."] = true
L["Warning:"] = true
L["Individual overrides. The grouped toggles above take priority."] = true
L["Advanced - Individual Module Control"] = true

-- Section headers
L["Cast Bars"] = true
L["UI Systems"] = true
L["Enable All Action Bar Modules"] = true
L["Cast Bar"] = true

-- Toggle labels
L["Action Bars System"] = true
L["Micro Menu & Bags"] = true
L["Cooldown Timers"] = true
L["Minimap System"] = true
L["Buff Frame System"] = true
L["Dark Mode"] = true
L["Item Quality Borders"] = true
-- Character Panel
L["Character Panel"] = true
L["Modern reskin of the Blizzard character window."] = true
L["Enable Character Panel"] = true
L["Apply the DragonUI reskin to the character window."] = true
L["Class Portrait"] = true
L["Show your class icon in the portrait instead of your character's face."] = true
L["Class-Colored Level Text"] = true
L["Color the class name in the \"Level X Race Class\" line."] = true
-- Pets & Mounts
L["Pets & Mounts"] = true
L["A dedicated window for your mounts and companion pets, replacing the old Pet tab of the character window."] = true
L["Enable Pets & Mounts"] = true
L["Add the Pets & Mounts micro menu button and its window."] = true
L["Enable Enhanced Tooltips"] = true
L["KeyBind Mode"] = true
L["Quest Tracker"] = true
L["Version Check"] = true

-- Module toggle descriptions
L["Enable DragonUI player castbar styling."] = true
L["Enable DragonUI target castbar styling."] = true
L["Enable DragonUI focus castbar styling."] = true
L["Master toggle for the complete action bars system."] = true
L["Includes main bars, vehicle, stance, pet, totem bars, and button styling."] = true
L["Micro menu and bags styling."] = true
L["Show cooldown timers on action buttons."] = true
L["Minimap styling, tracking icons, and calendar."] = true
L["Buff frame styling and toggle button."] = true
L["Separate Weapon Enchants"] = true
L["Detach weapon enchant icons (poisons, sharpening stones, etc.) from the buff bar into their own independently moveable frame. Position it freely using Editor Mode."] = true

-- Auras tab
L["Show Toggle Button"] = true
L["Show a collapse/expand button next to the buff icons."] = true
L["Weapon Enchants"] = true
L["Weapon enchant icons include rogue poisons, sharpening stones, wizard oils, and similar temporary weapon enhancements."] = true
L["Aura Borders"] = true
L["Enable Aura Borders"] = true
L["Show modern borders around buff and debuff icons."] = true
L["Buff Border Color"] = true
L["Border Style"] = true
L["Rounded"] = true
L["Square"] = true
L["When enabled, a 'Weapon Enchants' mover appears in Editor Mode that you can drag to any position on screen."] = true
L["Positions"] = true
L["Player Buffs & Debuffs"] = true
L["Layout settings for the player buff and debuff bar. These do not affect target or focus auras."] = true
L["Buff Order"] = true
L["Default (Blizzard)"] = true
L["How to sort player buff icons on the buff bar."] = true
L["Player Buffs First"] = true
L["Other Player Buffs First"] = true
L["Duration Buffs First"] = true
L["Buffs Per Row"] = true
L["Debuffs Per Row"] = true
L["How many buff icons to show in each row."] = true
L["How many debuff icons to show in each row."] = true
L["Max Buff Rows"] = true
L["Max Debuff Rows"] = true
L["Maximum number of buff rows to display. Use 0 for no limit."] = true
L["Maximum number of debuff rows to display. Use 0 for no limit."] = true
L["Buff Horizontal Gap"] = true
L["Debuff Horizontal Gap"] = true
L["Buff Vertical Gap"] = true
L["Debuff Vertical Gap"] = true
L["Space between buff rows."] = true
L["Space between debuff rows."] = true
L["Debuff Attached Offset Y"] = true
L["Vertical gap below the buff bar when debuffs are attached (not detached in Editor Mode)."] = true
L["Layout Preview"] = true
L["Shows fake buff and debuff icons so you can tune scale, rows, and spacing without needing real auras. Turn this off when finished."] = true
L["Enable Layout Preview"] = true
L["Preview Buff Count"] = true
L["Preview Debuff Count"] = true
L["Reset Buff Frame Position"] = true
L["Reset Weapon Enchant Position"] = true
L["Reset Debuff Position"] = true
L["Buff frame position reset."] = true
L["Weapon enchant position reset."] = true
L["Debuff position reset."] = true
L["Debuffs detached - positioned freely via Editor Mode"] = true
L["Debuffs attached - follow buff row"] = true
L["Target & Focus Aura Customization"] = true
L["Customize target/focus aura icons and timers."] = true
L["Aura Timers"] = true
L["Show aura timers on Target and Focus independently."] = true
L["Aura Icon Customization"] = true
L["Customize icon size, scale, and stack text for target/focus auras."] = true
L["Customize Aura Icons"] = true
L["Enable custom icon styling for target/focus aura icons."] = true
L["Target Aura Timer Settings"] = true
L["Enable Target Aura Timers"] = true
L["Target Aura Timer Size"] = true
L["Target Aura Minimum Duration (Seconds)"] = true
L["Target Aura Maximum Duration (Minutes)"] = true
L["Focus Aura Timer Settings"] = true
L["Enable Focus Aura Timers"] = true
L["Focus Aura Timer Size"] = true
L["Focus Aura Minimum Duration (Seconds)"] = true
L["Focus Aura Maximum Duration (Minutes)"] = true
L["Only show aura timers when remaining duration is above this value (seconds)."] = true
L["Only show aura timers when remaining duration is below this value (minutes). Use 0 to disable this limit."] = true
L["Timer Text Settings"] = true
L["Aura Buffs"] = true
L["Aura Debuffs"] = true
L["Duration Text Anchor"] = true
L["Duration X Offset"] = true
L["Duration Y Offset"] = true
L["Stack Text Settings"] = true
L["Stack Text Anchor"] = true
L["Stack X Offset"] = true
L["Stack Y Offset"] = true
L["Duration Font"] = true
L["Stack Font"] = true
L["Actionbar Font"] = true
L["Primary Font"] = true
L["Narrow Font"] = true
L["Arial Font"] = true
L["System Font"] = true
L["Aura Size"] = true
L["Auras Per Row"] = true
L["Discrete size steps: how many auras fit in a full-width row. 6 is the Blizzard default (17px). Your own auras render slightly larger, and rows beside a visible Target-of-Target are narrower, so fewer may fit there."] = true
L["Buff Icon Size"] = true
L["Buff Icon Scale"] = true
L["Buff Stack Font Size"] = true
L["Debuff Icon Size"] = true
L["Debuff Icon Scale"] = true
L["Debuff Stack Font Size"] = true
L["Background Plates Opacity"] = true
L["Controls the opacity of non-target nameplates while fade is active (0.0 - 1.0)."] = true
L["No Target: Full Opacity"] = true
L["When you have no target, show all nameplates at full opacity."] = true
L["Party/Raid: Full Opacity"] = true
L["Always show party and raid member nameplates at full opacity, regardless of target or fade settings. Does not affect pets or NPCs."] = true
L["Level Format"] = true
L["Show Debuff Position Debug Box"] = true
L["Displays a box showing where the debuff icon row starts and ends, even when no debuffs are active."] = true
L["Shade Fill"] = true
L["Quadrant Sweep"] = true
L["Square Radial Sweep"] = true
L["Reset Aura Customization"] = true
L["Reset Aura Timers"] = true
L["Aura timer settings reset."] = true
L["Aura icon customization settings reset."] = true

L["DragonUI quest tracker positioning and styling."] = true
L["LibKeyBound integration for intuitive hover + key press binding."] = true
L["Broadcast and detect addon version updates across group members."] = true

-- Toggle keybinding mode description

-- Enable/disable dynamic descriptions
L["Enable/disable "] = true

-- Dark Mode
L["Light (subtle)"] = true
L["Medium (balanced)"] = true
L["Dark (maximum)"] = true
L["Apply darker tinted textures to all UI elements."] = true
L["Darkens UI borders and chrome only: action bar borders, unit frame borders, minimap border, bag slot borders, micro menu, castbar borders, and decorative elements. Icons, portraits, and abilities are never affected."] = true
L["Enable Dark Mode"] = true

-- Dark Mode - Custom Color
L["Custom Color"] = true
L["Override presets with a custom tint color."] = true
L["Tint Color"] = true
L["Intensity"] = true

-- Range Indicator
L["Tints action button icons based on range and usability: red = out of range, blue = not enough mana, gray = unusable."] = true
L["Enable Range Indicator"] = true
L["Color action button icons when target is out of range or ability is unusable."] = true
L["Out of Range Color"] = true
L["Not Enough Mana Color"] = true

-- Key Press
L["Key Press"] = true
L["Fires action bar abilities the instant you press a key instead of when you release it, shaving reaction-time latency. Most useful for interrupts, dispels, and PvP."] = true
L["Enable Key Press"] = true
L["Fire abilities on key press instead of key release."] = true

-- Item Quality Borders
L["Enable Item Quality Borders"] = true
L["Show quality-colored borders on items in bags, character panel, bank, merchant, and inspect frames."] = true
L["Adds quality-colored glow borders to items in your bags, character panel, bank, merchant, and inspect frames: green = uncommon, blue = rare, purple = epic, orange = legendary."] = true
L["Minimum Quality"] = true
L["Poor"] = true
L["Common"] = true
L["Uncommon"] = true
L["Rare"] = true
L["Epic"] = true
L["Legendary"] = true

-- Loot Window
L["Loot Window"] = true
L["Configure the DragonUI loot window."] = true
L["Enable Loot Window"] = true
L["Apply the DragonUI skin to the Blizzard loot window."] = true
L["Open at Cursor"] = true
L["Open the loot window at the cursor instead of its saved position."] = true
L["Disable Open at Cursor, then drag the loot window to save its position."] = true
L["Animate Loot Reflow"] = true
L["Smoothly close gaps and resize the loot window after collecting items."] = true
L["Reset Loot Window Position"] = true
L["Clear the saved position. The Blizzard default will be used next time you open the loot window."] = true

-- Item Level
L["Item Level"] = true
L["Enable Item Level"] = true
L["Show the item level on gear icons across bags, bank, character panel and more."] = true
L["Size of the item level number on the icon."] = true
L["Font"] = true
L["Default (Arial Narrow)"] = true
L["Outline"] = true
L["Thickness of the black outline. WoW 3.3.5a has no real bold, so a thicker outline is what makes the number look heavier."] = true
L["Thick"] = true
L["Vertical position of the item level number on the icon."] = true
L["Average Item Level"] = true
L["Show the average item level of equipped gear on the character and inspect panels."] = true
L["Show in Tooltip"] = true
L["Also enable Blizzard's own item level line in item tooltips."] = true
L["Choose where the number appears:"] = true
L["Guild Bank"] = true
L["Inspect"] = true
L["Merchant"] = true
L["Retail-style vendor window chrome"] = true
L["Trade"] = true
L["Loot"] = true
L["Mail"] = true
L["Auction House"] = true

-- Enhanced Tooltips
L["Enhanced Tooltips"] = true
L["Improves GameTooltip with class-colored borders, class-colored names, target-of-target info, and styled health bars."] = true
L["Activate all tooltip improvements. Sub-options below control individual features."] = true
L["Class-Colored Border"] = true
L["Color the tooltip border by the unit's class (players) or reaction (NPCs)."] = true
L["Class-Colored Name"] = true
L["Color the unit name text in the tooltip by class color (players only)."] = true
L["Add a 'Targeting: <name>' line showing who the unit is targeting."] = true
L["Styled Health Bar"] = true
L["Restyle the tooltip health bar with class/reaction colors and slimmer look."] = true
L["Anchor to Cursor"] = true
L["Make the tooltip follow the cursor position instead of the default anchor."] = true
L["Show Aura Source"] = true
L["Show the caster's name (class-colored) on buff and debuff tooltips."] = true
L["Aura Tooltips"] = true
L["Show Aura Spell ID"] = true
L["Show the spell ID on buff and debuff tooltips. Requires the Tooltip module."] = true

-- Chat Mods
L["Enable Chat Mods"] = true
L["Enables or disables Chat Mods."] = true
L["Show Link Tooltips on Hover"] = true
L["Show tooltips for supported chat links without holding Alt."] = true
L["Editbox Position"] = true
L["Choose where the chat editbox is positioned."] = true
L["Top"] = true
L["Bottom"] = true
L["Left"] = true
L["Right"] = true
L["Anchor"] = true
L["Middle"] = true
L["Tab & Button Fade"] = true
L["How visible chat tabs are when not hovered. 0 = fully hidden, 1 = fully visible."] = true
L["Chat Style Opacity"] = true
L["Minimum opacity of the custom chat background. At 0 it fades with tabs; above 0 it stays partially visible when idle."] = true
L["Text Box Min Opacity"] = true
L["Minimum opacity of the text input box when idle. At 0 it fades with tabs; above 0 it stays partially visible."] = true
L["Chat Style"] = true
L["Visual style for the chat frame background."] = true
L["Editbox Style"] = true
L["Visual style for the chat input box background."] = true
L["Vanilla Editbox"] = true
L["Use the default chat input appearance."] = true
L["Dark"] = true
L["DragonUI Style"] = true
L["Nocturne"] = true

-- Bagster
L["Enable Bagster"] = true
L["All-in-one bag replacement with item filtering, search, quality indicators, and bank integration."] = true

-- Item usability tint
L["Item Usability"] = true
L["Tint Unusable Items"] = true
L["Color icons red for gear and usable items your character cannot equip or use (wrong armor type, level, class, etc.)."] = true

-- Alt Gold
L["Alt Gold"] = true
L["Enable Alt Gold"] = true
L["Hover the coins in your bags to list the gold of every character that has logged in with DragonUI."] = true
L["Show a tooltip with your other characters' gold when hovering the money in bags."] = true
L["Show All Realms"] = true
L["List characters from every realm instead of only the realm you are playing on."] = true

-- Bag Sort
L["Bag Sort"] = true
L["Enable Bag Sort"] = true
L["Sort buttons for bags and bank. Sorts items by type, rarity, level, and name."] = true
L["Add sort buttons to bag and bank frames. Also enables /sort and /sortbank slash commands."] = true
L["Fill Bank Stacks from Bags"] = true
L["Pull matching items from your bags into partial bank stacks when sorting the bank."] = true
L["Lock Toggle Hotkey"] = true
L["Choose the modifier + mouse button used to lock or unlock a bag slot while hovering it."] = true
L["Use /sortlock to lock or unlock the currently hovered slot from chat."] = true
L["Lock Icon Color"] = true
L["Color used to tint the padlock icon shown on locked bag/bank slots."] = true
L["Reverse Stack Order"] = true
L["Stack sorted items from the end of each bag so empty slots stay at the top."] = true
L["Alt + Left Click"] = true
L["Ctrl + Left Click"] = true
L["Shift + Left Click"] = true
L["Alt + Right Click"] = true
L["Ctrl + Right Click"] = true
L["Shift + Right Click"] = true
L["Alt + Middle Click"] = true
L["Ctrl + Middle Click"] = true
L["Shift + Middle Click"] = true

L["Show 'All' Tab"] = true
L["Show the 'All' category tab that displays all items without filtering."] = true
L["Equipment"] = true
L["Usable"] = true
L["Show Equipment Tab"] = true
L["Show the Equipment category tab for armor and weapons."] = true
L["Show Usable Tab"] = true
L["Show the Usable category tab for consumables and devices."] = true
L["Show Quest Tab"] = true
L["Show the Quest items category tab."] = true
L["Show Trade Goods Tab"] = true
L["Show the Trade Goods category tab (includes gems and recipes)."] = true
L["Show Miscellaneous Tab"] = true
L["Show the Miscellaneous items category tab."] = true
L["Left Side Tabs"] = true
L["Place category filter tabs on the left side of the bag frame instead of the right."] = true
L["Place category filter tabs on the left side of the bank frame instead of the right."] = true
L["Subtabs"] = true
L["Configure which bottom subtabs appear within each category tab. Applies to both inventory and bank."] = true
L["Normal"] = true
L["Trade Bags"] = true
L["Show the Normal bags subtab (non-profession bags)."] = true
L["Show the Trade bags subtab (profession bags)."] = true
L["Show the Armor subtab."] = true
L["Show the Weapon subtab."] = true
L["Show the Trinket subtab."] = true
L["Show the Consumable subtab."] = true
L["Show the Devices subtab."] = true
L["Show the Trade Goods subtab."] = true
L["Show the Gem subtab."] = true
L["Show the Recipe subtab."] = true
L["Configure Bagster bag replacement settings."] = true
L["Inventory Tabs"] = true
L["Bank Tabs"] = true
L["Inventory"] = true
L["Bank"] = true
L["Choose which category tabs appear on the inventory bag frame."] = true
L["Choose which category tabs appear on the bank frame."] = true
L["Gold Display"] = true
L["Text Only"] = true
L["Gold Icons"] = true
L["(disabled by Colorblind Mode)"] = true
L["Item Scale"] = true
L["Maximum size of item slots. The grid still shrinks them to fit the frame."] = true
L["Item Spacing"] = true
L["Gap between item slots in the grid."] = true
L["Quality Glow"] = true
L["Show a colored ring on uncommon and better items."] = true
L["Quest Item Glow"] = true
L["Highlight quest items with a golden border."] = true
L["Glow Intensity"] = true
L["Opacity of the quality ring on item slots."] = true
L["Quality Filter Row"] = true
L["Show the rarity filter dots at the bottom of the bag frame."] = true

-- Advanced modules - Fallback display names
L["Main Bars"] = true
L["Vehicle"] = true
L["Multicast"] = true
L["Buttons"] = true
L["Hide Blizzard Elements"] = true
L["Buffs"] = true
L["KeyBinding"] = true
L["Cooldowns"] = true

-- Advanced modules - RegisterModule display names (from module files)
L["Micro Menu"] = true
L["Loot Roll"] = true
L["Key Binding"] = true

-- Advanced modules - RegisterModule descriptions (from module files)
L["Chat Mods"] = true
L["Bagster"] = true

-- ============================================================================
-- ACTION BARS TAB
-- ============================================================================

-- Sub-tabs
L["Layout"] = true
L["Visibility"] = true

-- Scales section
L["Action Bar Scales"] = true
L["Main Bar Scale"] = true
L["Right Bar Scale"] = true
L["Left Bar Scale"] = true
L["Bottom Left Bar Scale"] = true
L["Bottom Right Bar Scale"] = true
L["Extra Bar Scale"] = true
L["Bar"] = true
L["Reset All Scales"] = true
L["All action bar scales reset to 0.9"] = true

-- Positions section
L["Action Bar Positions"] = true
L["Left Bar Horizontal"] = true
L["Make the left secondary bar horizontal instead of vertical."] = true
L["Right Bar Horizontal"] = true
L["Make the right secondary bar horizontal instead of vertical."] = true

-- Button Appearance section
L["Button Appearance"] = true
L["Main Bar Only Background"] = true
L["Only the main action bar buttons will have a background."] = true
L["Hide Main Bar Background"] = true
L["Hide the background texture of the main action bar."] = true

-- Text visibility
L["Text Visibility"] = true
L["Show Count Text"] = true
L["Show Hotkey Text"] = true
L["Range Indicator"] = true
L["Show range indicator dot on buttons."] = true
L["Show Macro Names"] = true
L["Show Page Numbers"] = true

-- Cooldown text
L["Cooldown Text"] = true
L["Min Duration"] = true
L["Minimum duration for cooldown text to appear."] = true
L["Cooldown Text Color"] = true
L["Size of cooldown text."] = true

-- Colors
L["Colors"] = true
L["Macro Text Color"] = true
L["Hotkey Text Color"] = true
L["Hotkey Font Size"] = true
L["Hotkey Shadow Color"] = true
L["Border Color"] = true

-- Gryphons
L["Gryphons"] = true
L["End-cap ornaments flanking the main action bar."] = true
L["Gryphon previews are hidden while D3D9Ex is active to avoid client crashes."] = true
L["Style"] = true
L["Gryphon Scale"] = true
L["Gryphon Offset X"] = true
L["Gryphon Offset Y"] = true
L["Moves both gryphons inward or outward, mirrored left/right."] = true
L["Flying"] = true
L["Classic"] = true
L["Dragonflight"] = true
L["Hidden"] = true
L["Dragonflight (Wyvern)"] = true
L["Dragonflight (Gryphon)"] = true

-- Layout section
L["Main Bar Layout"] = true
L["Bottom Left Bar Layout"] = true
L["Bottom Right Bar Layout"] = true
L["Right Bar Layout"] = true
L["Left Bar Layout"] = true
L["Configure the main action bar grid layout. Rows are determined automatically from columns and buttons shown."] = true
L["Columns"] = true
L["Buttons Shown"] = true
L["Change Button Order"] = true
L["Button Order"] = true
L["Quick Presets"] = true
L["Apply layout presets to multiple bars at once."] = true
L["Both 1x12"] = true
L["Both 2x6"] = true
L["Reset All"] = true
L["All bar layouts reset to defaults."] = true

-- Visibility section
L["Bar Visibility"] = true
L["Control when action bars are visible. Bars can show only on hover, only in combat, or both. When no option is checked the bar is always visible."] = true
L["Enable / Disable Bars"] = true
L["Bottom Left Bar"] = true
L["Bottom Right Bar"] = true
L["Right Bar"] = true
L["Left Bar"] = true
L["Main Bar"] = true
L["Always Hidden"] = true
L["Show on Hover Only"] = true
L["Show in Combat Only"] = true
L["Hide the main bar until you hover over it."] = true
L["Hide the main bar until you enter combat."] = true
L["Hide the main bar while in combat."] = true
L["Hover/Combat Logic"] = true
L["When both hover and combat are enabled, choose whether both are required (AND) or either condition is enough (OR)."] = true
L["Fade the quest tracker until you hover over it."] = true
L["Fade the quest tracker until you enter combat."] = true
L["Hide the quest tracker while in combat."] = true
L["Fade the XP and Reputation bars until you hover over them."] = true
L["Fade the XP and Reputation bars until you enter combat."] = true
L["Hide the XP and Reputation bars while in combat."] = true
L["Fade the player frame until you hover over it."] = true
L["Fade the player frame until you enter combat."] = true
L["Also fades the Target of Target and target cast bar, attached or not."] = true
L["Fade the target frame group until you hover over it."] = true
L["Fade the target frame group until you enter combat."] = true
L["Also fades the Target of Focus and focus cast bar, attached or not."] = true
L["Fade the focus frame group until you hover over it."] = true
L["Fade the focus frame group until you enter combat."] = true
L["Fade the pet frame until you hover over it."] = true
L["Fade the pet frame until you enter combat."] = true
L["Fade party frames until you hover over them."] = true
L["Fade party frames until you enter combat."] = true
L["Fade boss frames until you hover over them."] = true
L["Fade boss frames until you enter combat."] = true
L["Boss"] = true
L["Fade the stance bar until you hover over it."] = true
L["Fade the stance bar until you enter combat."] = true
L["Fade the pet bar until you hover over it."] = true
L["Fade the pet bar until you enter combat."] = true
L["Show the button frame on pet slots with no ability assigned."] = true
L["Fade the totem bar until you hover over it."] = true
L["Fade the totem bar until you enter combat."] = true
L["Fade the minimap until you hover over it."] = true
L["Fade the minimap until you enter combat."] = true
L["Experimental:"] = true
L["Fading the minimap can occasionally cause tracking icons to stop updating until you /reload. Use at your own risk."] = true
L["Has no effect while SexyMap controls the minimap (SexyMap or Hybrid mode)."] = true
L["Hide in Combat"] = true
L["Hide the minimap while in combat."] = true
L["AND (both required)"] = true
L["OR (either condition)"] = true
L["Bag Bar"] = true

-- ============================================================================
-- ADDITIONAL BARS TAB
-- ============================================================================

L["Bars that appear based on your class and situation."] = true

-- Common settings
L["Button Size"] = true
L["Button Spacing"] = true

-- Stance Bar
L["Stance Bar"] = true
L["X Position"] = true
L["Y Position"] = true

-- Pet Bar
L["Pet Bar"] = true
L["Show Empty Slots"] = true

-- Vehicle Bar
L["Vehicle Bar"] = true
L["Blizzard Art Style"] = true
L["Use Blizzard vehicle bar art with health/power display. Requires reload."] = true

-- Totem Bar
L["Totem Bar (Shaman)"] = true

-- Extra Bar (issue #330)
L["Extra Bar"] = true
L["A 12-button action bar independent of every class's bonus bar (stance/stealth/vehicle)."] = true
L["Fade the extra bar until you hover over it."] = true
L["Fade the extra bar until you enter combat."] = true

-- ============================================================================
-- CAST BARS TAB
-- ============================================================================

L["Player Castbar"] = true
L["Target Castbar"] = true
L["Focus Castbar"] = true

-- Sub-tabs
L["Player"] = true
L["Target"] = true
L["Focus"] = true

-- Common options
L["Width"] = true
L["Height"] = true
L["Scale"] = true
L["Show Icon"] = true
L["Icon Size"] = true
L["Modern Icon Border"] = true
L["Modern Icon Border Desc"] = "Frame the spell icon with the DragonUI action-bar border instead of the classic ring."
L["Modern Icon Border Debuff Desc"] = "Frame aura icons with the DragonUI action-bar border."
L["Text Mode"] = true
L["Simple (Name Only)"] = true
L["Detailed (Name + Time)"] = true
L["Time Precision"] = true
L["Decimal places for remaining time."] = true
L["Max Time Precision"] = true
L["Decimal places for total time."] = true
L["Hold Time (Success)"] = true
L["How long the bar stays after a successful cast."] = true
L["Hold Time (Interrupt)"] = true
L["How long the bar stays after being interrupted."] = true
L["Reset Position"] = true
L["Player castbar position reset."] = true
L["Castbar detached - positioned freely via Editor Mode"] = true
L["Castbar attached - follows Target frame"] = true
L["Castbar attached - follows Focus frame"] = true
L["Re-attach Castbar to Target"] = true
L["Re-attach Castbar to Focus"] = true

-- Width/height descriptions for target/focus

-- Latency indicator (player only)
L["Latency Indicator"] = true
L["Enable Latency Indicator"] = true
L["Show a safe-zone overlay based on real cast latency."] = true
L["Latency Color"] = true
L["Latency Alpha"] = true
L["Opacity of the latency indicator."] = true

-- ============================================================================
-- ENHANCEMENTS TAB
-- ============================================================================

L["Enhancements"] = true
L["Visual enhancements that add Dragonflight-style polish to the UI. These are optional \226\128\148 disable any you don't want."] = true

-- (Dark Mode, Range Indicator, Item Quality, Tooltips defined above in MODULES section)

-- ============================================================================
-- MICRO MENU TAB
-- ============================================================================

L["Grayscale Icons"] = true
L["Use grayscale icons instead of colored icons."] = true
L["Menu Scale"] = true
L["Icon Spacing"] = true
L["Padding between micromenu buttons."] = true
L["Number of micromenu button columns. Set to 1 for a vertical stack."] = true
L["Invert Button Order"] = true
L["Reverse the order of micromenu buttons in the grid."] = true
L["Hide on Vehicle"] = true
L["Hide micromenu and bags while in a vehicle."] = true
L["Show Latency Indicator"] = true
L["Show a colored bar below the Help button indicating connection quality (green/yellow/red). Requires UI reload."] = true

-- Bags
L["Bags"] = true
L["Bag Bar Scale"] = true

-- XP & Rep Bars

-- ============================================================================
-- MINIMAP TAB
-- ============================================================================

L["Minimap Buttons Collector"] = true
L["Circle"] = true
L["Arrow"] = true
L["Basic Settings"] = true
L["Border Alpha"] = true
L["Top border alpha (0 to hide)."] = true
L["Addon Button Skin"] = true
L["Apply DragonUI border styling to addon icons."] = true
L["Addon Button Fade"] = true
L["Addon icons fade out when not hovered."] = true
L["Player Arrow Size"] = true
L["New Blip Style"] = true
L["Use newer-style minimap blip icons."] = true
L["Minimap Decorations"] = true
L["Border presets from SexyMap by funkydude, used with permission."] = true
L["Adds decorative animated texture layers around the DragonUI minimap."] = true
L["Enable Minimap Decorations"] = true
L["Animated Effects"] = true
L["Rotate preset layers when the selected preset includes animation."] = true
L["Hide DragonUI Border"] = true

-- Time & Calendar
L["Time & Calendar"] = true
L["Show Clock"] = true
L["Show Calendar"] = true
L["Clock Font Size"] = true

-- Display Settings
L["Display Settings"] = true
L["Tracking Icons"] = true
L["Show current tracking icons (old style)."] = true
L["Zoom Buttons"] = true
L["Show zoom buttons (+/-)."] = true
L["Zone Text Font Size"] = true
L["Font size of the zone text above the minimap."] = true

-- Position
L["Position"] = true

-- ============================================================================
-- QUEST TRACKER TAB
-- ============================================================================

L["Position and display settings for the objective tracker."] = true
L["Show Header Background"] = true
L["Show/hide the decorative header background texture."] = true
L["Top Right"] = true
L["Top Left"] = true
L["Bottom Right"] = true
L["Bottom Left"] = true
L["Center"] = true
L["Font size for quest tracker text"] = true
L["Custom Height"] = true
L["Limit the tracker to a fixed height. When off, it stops above the bags. Quests that don't fit are hidden until there is room."] = true
L["Maximum height of the quest tracker."] = true

-- ============================================================================
-- UNIT FRAMES TAB
-- ============================================================================

-- Sub-tabs
L["Pet"] = true
L["ToT / ToF"] = true
L["Party"] = true

-- Common options
L["Class Color Health"] = true
L["Class icon instead of 3D model for players."] = true
L["Alternative Class Icons"] = true
L["Use DragonUI alternative class icons instead of Blizzard's class icon atlas."] = true
L["Format Large Numbers"] = true
L["Text Format"] = true

-- Text format values
L["Current Value"] = true
L["Percentage"] = true
L["Numbers + %"] = true
L["Current / Max"] = true

-- Party text format values

-- Health/Mana text
L["Always Show Health Text"] = true
L["Always Show Mana Text"] = true

-- Player frame specific
L["Player Frame"] = true
L["Dragon Decoration"] = true
L["None"] = true
L["Elite (Golden)"] = true
L["RareElite (Winged)"] = true
L["Glow Effects"] = true
L["Show Rest Glow"] = true
L["Golden glow around the player frame when resting (inn or city). Works with all frame modes."] = true
L["Show Combat Flash"] = true
L["Pulsing glow effect when entering combat. Works with all frame modes."] = true
L["Combat Flash Opacity"] = true
L["Maximum opacity of the combat flash pulse effect."] = true
L["Alternate Mana (Druid)"] = true
L["Always Show"] = true
L["Druid mana text visible at all times, not just on hover."] = true
L["Percentage + Current/Max"] = true

-- Fat Health Bar
L["Fat Health Bar"] = true
L["Enable"] = true
L["Full-width health bar. Auto-disabled in vehicles."] = true
L["Hide Mana Bar"] = true
L["Completely hide the mana bar when Fat Health Bar is active."] = true
L["Mana Bar Width"] = true
L["Mana Bar Height"] = true
L["Mana Bar Texture"] = true
L["Choose the texture style for the power/mana bar. Only applies in Fat Health Bar mode."] = true
L["DragonUI (Default)"] = true
L["Blizzard Classic"] = true
L["Flat Solid"] = true
L["Smooth"] = true
L["Aluminium"] = true
L["LiteStep"] = true

-- Power Bar Colors
L["Power Bar Colors"] = true
L["Mana"] = true
L["Rage"] = true
L["Energy"] = true
-- L["Focus"] = true  -- Already defined above
L["Runic Power"] = true
L["Happiness"] = true
L["Runes"] = true
L["Reset Colors to Default"] = true

-- Target frame
L["Target Frame"] = true
L["Threat Glow"] = true
L["Show Name Background"] = true
L["Show the colored name background behind the target name."] = true

-- Focus frame
L["Focus Frame"] = true
L["Show the colored name background behind the focus name."] = true
L["Show Buff/Debuff on Focus"] = true
L["Uses the native large focus frame mode to show buffs and debuffs on the focus frame."] = true
L["Override Position"] = true
L["Move the pet frame independently from the player frame."] = true

-- Pet frame
L["Pet Frame"] = true

-- Target of Target
L["Target of Target"] = true
L["Follows the Target frame by default. Move it in Editor Mode (/dragonui edit) to detach and position freely."] = true
L["Detached \226\128\148 positioned freely via Editor Mode"] = true
L["Attached \226\128\148 follows Target frame"] = true
L["Re-attach to Target"] = true

-- Target of Focus
L["Target of Focus"] = true
L["Follows the Focus frame by default. Move it in Editor Mode (/dragonui edit) to detach and position freely."] = true
L["Attached \226\128\148 follows Focus frame"] = true
L["Re-attach to Focus"] = true

-- Party Frames
L["Party Frames"] = true

-- Boss Frames
L["Boss Frames"] = true
L["Enabled"] = true

L["Orientation"] = true
L["Vertical"] = true
L["Horizontal"] = true
L["Vertical Padding"] = true
L["Space between party frames in vertical mode."] = true
L["Horizontal Padding"] = true
L["Space between party frames in horizontal mode."] = true

-- ============================================================================
-- XP & REP BARS TAB
-- ============================================================================

L["Bar Style"] = true
L["XP / Rep Bar Style"] = true
L["DragonflightUI: fully custom bars with rested XP background.\nRetailUI: atlas-based reskin of Blizzard bars.\n\nChanging style requires a UI reload."] = true
L["DragonflightUI"] = true
L["RetailUI"] = true
L["XP bar style changed to "] = true
L["A UI reload is required to apply this change."] = true

-- Size & Scale
L["Size & Scale"] = true
L["Height of the XP and Reputation bars (in pixels)."] = true
L["Width of the XP and Reputation bars (in pixels)."] = true
L["Experience Bar Scale"] = true
L["Scale of the experience bar."] = true
L["Reputation Bar Scale"] = true
L["Scale of the reputation bar."] = true

-- Rested XP
L["Rested XP"] = true
L["Show Rested XP Background"] = true
L["Display a translucent bar showing the total available rested XP range.\n(DragonflightUI style only)"] = true
L["Show Exhaustion Tick"] = true
L["Show the exhaustion tick indicator on the XP bar, marking where rested XP ends."] = true

-- Text Display
L["Text Display"] = true
L["Always Show Text"] = true
L["Always display XP/Rep text instead of only on hover."] = true
L["Show XP Percentage"] = true
L["Display XP percentage alongside the value text."] = true

-- ============================================================================
-- PROFILES TAB
-- ============================================================================

L["Database not available."] = true
L["Save and switch between different configurations per character."] = true
L["Current Profile"] = true
L["Active: "] = true
L["Switch or Create Profile"] = true
L["Select Profile"] = true
L["New Profile Name"] = true
L["Default Profile"] = true
L["New characters will use this profile."] = true
L["New characters will get their own profile."] = true
L["New characters will start on profile: "] = true
L["Copy From"] = true
L["Copies all settings from the selected profile into your current one."] = true
L["Copied profile: "] = true
L["Delete Profile"] = true
L["Warning: Deleting a profile is permanent and cannot be undone."] = true
L["Delete"] = true
L["Deleted profile: "] = true
L["Are you sure you want to delete the profile '%s'? This cannot be undone."] = true
L["Reset Current Profile"] = true
L["Restores the current profile to its defaults. This cannot be undone."] = true
L["Reset Profile"] = true
L["All changes will be lost and the UI will be reloaded.\nAre you sure you want to reset your profile?"] = true
L["Profile reset to defaults."] = true

-- UNIT FRAME LAYERS MODULE
L["Unit Frame Layers"] = true
L["Enable Unit Frame Layers"] = true
L["Heal prediction bars, absorb shields, and animated health loss overlays on unit frames."] = true
L["Show heal prediction, absorb shields, and animated health loss on all unit frames."] = true
L["Animated Health Loss"] = true
L["Show animated red health loss bar on player frame when taking damage."] = true
L["Missing Health Text"] = true
L["Show the health deficit (missing health) as red text on health bars. Useful for healers."] = true

-- LAYOUT PRESETS
L["Layout Presets"] = true
L["Save and restore complete UI layouts. Each preset captures all positions, scales, and settings."] = true
L["No presets saved yet."] = true
L["Save New Preset"] = true
L["Save your current UI layout as a new preset."] = true
L["Preset"] = true
L["Enter a name for this preset:"] = true
L["Save"] = true
L["Load"] = true
L["Load preset '%s'? This will overwrite your current layout settings."] = true
L["Load Preset"] = true
L["Delete preset '%s'? This cannot be undone."] = true
L["Delete Preset"] = true
L["Duplicate Preset"] = true
L["Preset saved: "] = true
L["Preset loaded: "] = true
L["Preset deleted: "] = true
L["Preset duplicated: "] = true
L["Also delete all saved layout presets?"] = true
L["Also delete all saved position presets?"] = true
L["Presets kept."] = true
L["Position presets kept."] = true

-- PRESET IMPORT / EXPORT
L["Export Preset"] = true
L["Import Preset"] = true
L["Import a preset from a text string shared by another player."] = true
L["Import"] = true
L["Select All"] = true
L["Hover Fade"] = true
L["Visible Alpha"] = true
L["Opacity when a bar is considered visible by hover/combat rules."] = true
L["Hidden Alpha"] = true
L["Opacity when a bar is hidden by hover/combat rules. Set above 0 to keep bars faintly visible."] = true
L["Fade In Duration"] = true
L["Seconds used to fade bars in when they become visible."] = true
L["Fade Out Duration"] = true
L["Seconds used to fade bars out when they become hidden."] = true
L["Fade Out Delay"] = true
L["Delay before hover-out starts fading, useful to avoid flicker between buttons."] = true
L["Close"] = true
L["Enter a name for the imported preset:"] = true
L["Imported Preset"] = true
L["Preset imported: "] = true
L["Invalid preset string."] = true
L["Not a valid DragonUI preset string."] = true
L["Failed to export preset."] = true

-- ============================================================================
-- NAMEPLATES
-- ============================================================================

L["Nameplates"] = true
L["Enable Nameplates Module"] = true
L["Apply DragonUI nameplate styling."] = true
L["Plate Style"] = true
L["Nameplate Art"] = true
L["Heritage is the DragonUI art. Modern draws the current World of Warcraft nameplate chrome and is still in beta."] = true
L["Modern (Beta)"] = true
L["Heritage"] = true
L["Mouseover Highlight"] = true
L["Wash the health bar with a bright overlay while the cursor is over the nameplate."] = true
L["Target Selection Border"] = true
L["Draw the white glowing border around the current target's health bar."] = true
L["Dim Non-Target Plates"] = true
L["Lay the retail dim overlay over every nameplate that is not your target."] = true
L["Retail Threat Colors"] = true
L["Use retail's yellow and orange threat steps instead of the yellow, orange and red set."] = true
L["Unit Nameplates"] = true
L["Friendly Units"] = true
L["Enemy Units"] = true
L["Pets"] = true
L["Guardians"] = true
L["Totems"] = true
L["Offset X"] = true
L["Offset Y"] = true
L["Bar Width"] = true
L["Bar Height"] = true
L["Font Size"] = true
L["Display"] = true
L["Health Text"] = true
L["What the health text shows. With both, the value comes first."] = true
L["Percent"] = true
L["Value"] = true
L["Value and Percent"] = true
L["After the name, the name is shortened so the two never overlap. With the name inside the health bar, the text always sits at the bar's right end."] = true
L["After the Name"] = true
L["Inside the Bar, Centered"] = true
L["Inside the Bar, Right"] = true
L["Inside the Bar, Value Left and Percent Right"] = true
L["Center Name"] = true
L["Center the name in the space the health text leaves free."] = true
L["Font size of the name, and of the health text when it follows the name (1-10, default 2)."] = true
L["Inset the name, level, and health text from the left and right edges of the health bar. Does not affect the elite icon."] = true
L["Show"] = true
L["Always (anyone's)"] = true
L["Follow 'Only My Debuffs'"] = true
L["Only Mine"] = true
L["Each listed spell can decide whose casts it shows, whatever 'Only My Debuffs' says."] = true
L["Click an entry to select it."] = true
L["Click to select."] = true
L["Remove Spell"] = true
L["Select a spell above to choose whose casts it shows."] = true
L["Name & Health"] = true
L["Name"] = true
L["Level"] = true
L["Name Position"] = true
L["Above the Health Bar"] = true
L["Inside the Health Bar"] = true
L["Moves the name up or down while it sits inside the health bar."] = true
L["The name is inside the health bar, so the health text sits at the bar's right end, after the name."] = true
L["The Modern style draws its own bar background."] = true
L["Name Text"] = true
L["Color friendly player names by class. Needs Party Class Colors or Friendly Class Colors."] = true
L["Color enemy player names by class. Needs Enemy Player Class Colors."] = true
L["Font size of the health text inside the bar (1-10). After the name, or in the Modern style, it matches the name."] = true
L["Text Outline"] = true
L["Black outline on the name and health text."] = true
L["Gray Tapped Units"] = true
L["Grays the health bar when a unit is tapped by another player or group."] = true
L["Friendly Player Color"] = true
L["Friendly NPC Color"] = true
L["Party Class Colors"] = true
L["Use class colors for party member nameplates instead of the friendly player color."] = true
L["Friendly Class Colors"] = true
L["Class-color every friendly player, not just your group. Party and raid show automatically; others fill in when you target or mouse over them, or instantly with awesome_wotlk."] = true
L["Headline Mode"] = true
L["Enable Headline Mode"] = true
L["Hide health, power and cast bars on friendly nameplates, showing only the name."] = true
L["Name Text Color"] = true
L["Friendly Players"] = true
L["Class colors, title, guild and AFK read from the unit: party/raid show automatically; others fill in when you target or mouse over them, or instantly with awesome_wotlk."] = true
L["Party / Raid Members"] = true
L["Apply headline mode to your party and raid members."] = true
L["All Friendly Players"] = true
L["Apply headline mode to all friendly players, not just your group."] = true
L["Show Class Colors"] = true
L["Show friendly player names in their class color."] = true
L["Show Player Title"] = true
L["Show the player's title with their name (e.g. \"Arthas Jenkins\")."] = true
L["Show Guild Name"] = true
L["Show the player's guild name below their name."] = true
L["Show AFK Status"] = true
L["Show an <AFK> tag for away players."] = true
L["Friendly NPCs"] = true
L["NPC titles fill in when you target or mouse over the NPC, or instantly with awesome_wotlk."] = true
L["Headline Mode for NPCs"] = true
L["Apply headline mode to friendly NPCs."] = true
L["Show NPC Title"] = true
L["Show the NPC's title or occupation below its name (e.g. <General Supplies>)."] = true
L["Show Full Plate on Target"] = true
L["When headline mode is active, show health, power and cast bars on your current target."] = true
L["Enemy Player Class Colors"] = true
L["Use class colors for enemy player nameplates."] = true
L["Show Level Always"] = true
L["Show Level In Name When Targeted"] = true
L["Show Level on Hover"] = true
L["Name Reaction Colors"] = true
L["Tint name text with the health bar reaction color (red/yellow/green/blue)."] = true
L["Class Colors on Friendly Names"] = true
L["Class Colors on Enemy Names"] = true

L["Show Target Highlight"] = true
L["Show Target Arrows"] = true
L["Left/right arrows on the targeted nameplate."] = true
L["Opacity"] = true
L["Disable Non-Target Fade"] = true
L["Only Show on Target & Focus"] = true
L["Only My Debuffs"] = true
L["Only show debuffs you applied yourself."] = true
L["Debuff List Mode"] = true
L["Whitelist"] = true
L["Blacklist"] = true
L["Add Debuff by Name"] = true
L["Add Debuff by ID"] = true
L["Export/Import Spell IDs"] = true
L["Enter a spell ID"] = true
L["Enter a spell name"] = true
L["Paste spell IDs separated by commas."] = true
L["Invalid spell name or ID"] = true
L["Click an entry to remove it."] = true
L["Click to remove."] = true
L["Spell filter list is empty."] = true
L["Spell ID: %d"] = true
L["Unknown"] = true
L["Power Bar"] = true
L["Debuffs"] = true
L["Auras"] = true
L["Max Aura Icons"] = true
L["Always Show Others' Crowd Control"] = true
L["Enemy Buffs"] = true
L["Show Enemy Buffs"] = true
L["Which Buffs"] = true
L["Purgeable & Defensive"] = true
L["Time Remaining"] = true
L["Colored Aura Borders"] = true
L["Friendly Plates"] = true
L["Show Auras on Allies"] = true
L["Show All Debuffs"] = true
L["Stuns, fears and polymorphs on an ally, listed or not."] = true
L["Every debuff, not just crowd control. Useful for spotting what to dispel."] = true
L["Always Show Defensive Cooldowns"] = true
L["Uses the defensive buff list from the Enemy Buffs section."] = true
L["Importance: crowd control first, then enemy defensives, then your own debuffs."] = true
L["Time Remaining: whatever expires soonest goes first."] = true
L["Highlighted auras draw larger than the rest."] = true
L["Always Highlight These Spells"] = true
L["Blizzard's dispel colors, editable below."] = true
L["Debuff List"] = true
L["Buff List"] = true
L["Shows buffs you can dispel or steal, plus the defensive cooldowns listed here."] = true
L["Stuns, fears, roots and polymorphs are detected automatically. Add anything the game does not flag."] = true
L["Icon Order"] = true
L["Order Icons By"] = true
L["Importance"] = true
L["Defensive Buff List"] = true
L["Always Show Crowd Control"] = true
L["Highlighted Auras"] = true
L["What Gets Highlighted"] = true
L["Crowd Control + List"] = true
L["Spell List Only"] = true
L["Nothing"] = true
L["Highlight Size"] = true
L["Multiplier over the base icon size."] = true
L["Magic"] = true
L["Curse"] = true
L["Disease"] = true
L["Poison"] = true
L["Enrage"] = true
L["No Dispel Type"] = true
L["Separate Color for Crowd Control"] = true
L["Aura Row"] = true
L["Show Auras"] = true
L["Show buffs and debuffs above nameplates."] = true
L["Buffs and debuffs share these slots."] = true
L["Aura Icon Size"] = true
L["Aura Horizontal Offset"] = true
L["Aura Vertical Offset"] = true
L["Timers"] = true
L["Show Cooldown Text"] = true
L["Time left on each icon."] = true
L["Cooldown Font Size"] = true
L["Cooldown Text Position"] = true
L["Show Cooldown Swipe"] = true
L["Radial sweep over the icon as it runs out."] = true
L["Cooldown Swipe Style"] = true
L["Border Colors"] = true
L["Crowd Control"] = true
L["Hide auras on every nameplate except your target and focus."] = true
L["Enemy crowd control matters no matter who cast it."] = true
L["Buffs share the row with debuffs, ordered by priority."] = true
L["Show Threat Glow"] = true
L["Show Power Bar"] = true
L["Show Power Bar Text"] = true
L["Show numeric values (current / percent) on the power bar."] = true
L["Show Cast Bars"] = true
L["Show Spell Name"] = true
L["Show the spell name text on the cast bar."] = true
L["Spell Name Font Size"] = true
L["Spell Name Offset X"] = true
L["Spell Name Offset Y"] = true
L["Cast Bar Height"] = true
L["Bar Stack Gap"] = true
L["Vertical spacing between health, power, and cast bars (pixels)."] = true
L["Show Party/Raid Cast Bars"] = true
L["Hide Pet Casts"] = true
L["Hide Pet Casts Desc"] = "Hide cast bars on player pets and guardians (Water Elemental, mirror images, etc.)."
L["Show cast bars when the unit is known for sure: your target, focus, mouseover, arena enemies, or a group member's target."] = true
L["Also show cast bars on party and raid allies, even when you are not targeting them."] = true
L["Off-Target Cast Bars"] = true
L["Enable Off-Target Detection"] = "Enable safe off-target detection"
L["Enable Off-Target Detection Desc"] = "Show cast bars on units you are not targeting, after you have used target, focus, or mouseover on them."
L["Off-Target Aggressive Mode"] = "Aggressive mode"
L["Off-Target Aggressive Mode Desc"] = "Show off-target casts without needing target, focus, or mouseover first."
L["Off-Target Players Only"] = "Players only"
L["Off-Target Players Only Desc"] = "Aggressive mode for players only. World mobs stay on safe mode."
L["Off-Target Aggressive Warning"] = "|cffffffffWarning:|r\n- If a cast is cancelled by moving or jumping (fake cast), the bar still runs to the end.\n- Same-name mobs may show the bar on the wrong nameplate."
L["Off-Target Players Only Warning"] = "|cffffffffWarning:|r\n- If a cast is cancelled by moving or jumping (fake cast), the bar still runs to the end."
L["Icons"] = true
L["Quest"] = true
L["Show Raid Markers"] = true
L["Show raid target markers (skull, cross, star, etc.) on nameplates."] = true
L["Beside Bar Layout"] = true
L["Place the raid marker beside the bar (as with DragonUI debuffs). Useful with other aura addons."] = true
L["Color Health Bar by Raid Marker"] = true
L["Colors the health bar with the raid marker's color, on both allies and enemies."] = true
L["Show Elite Icon"] = true
L["Show elite/rare dragon icon on nameplates."] = true
L["Elite Icon Style"] = true
L["Choose dragon or star style for elite and rare nameplate icons."] = true
L["Dragon"] = true
L["Star"] = true
L["Show Combo Points"] = true
L["Show combo points on the current target nameplate."] = true
L["Quest Icons"] = true
L["Show Quest Icons"] = true
L["Show kill/loot icons over your quest-objective mobs. Without awesome_wotlk, only your target, mouseover and focus show them."] = true
L["Resolve By Name"] = true
L["Match plate names to your active objectives so icons show on every plate without awesome_wotlk. Kill objectives work on their own; loot needs a quest addon below."] = true
L["Loot Database"] = true
L["Which quest addon supplies loot data (which mob drops a quest item). Auto picks the best loaded one."] = true
L["Auto"] = true
L["Icons With Questie"] = true
L["Who draws quest icons on plates when Questie is loaded with its own nameplate icons on. DragonUI disables Questie's (needs reload); Questie hides DragonUI's."] = true
L["Ask"] = true
L["Pointer Mode"] = true
L["Show a single quest marker on any objective mob instead of separate kill/loot icons."] = true
L["Kill Icon"] = true
L["Choose the icon shown for kill objectives."] = true
L["Sword"] = true
L["Skull"] = true
L["Elite"] = true
L["Elite Kill Icon"] = true
L["Show a distinct icon on elite and rare kill objectives."] = true
L["Loot Icon"] = true
L["Choose the icon shown for loot/collect objectives."] = true
L["Bag"] = true
L["Chest"] = true
L["Pointer"] = true
L["Pointer Icon"] = true
L["Off"] = true
L["Size"] = true
L["Icon"] = true
L["Test Preview"] = true
L["Preview Icon"] = true
L["Force one icon on all enemy nameplates so you can position and size it. Set to Off when done."] = true
L["Show Totem Icons"] = true
L["Totem Icon Only"] = true
L["Hide the totem's nameplate entirely and show only its icon."] = true
L["Show Totem Life Timer"] = true
L["Show remaining life on your own totems (requires their icon to be known)."] = true
L["Totems Without Icon"] = true
L["Comma-separated, exact totem names (as shown in-game) that should never get a totem icon and render as a normal nameplate instead."] = true
L["Totem Icon Position"] = true
L["Choose where the totem icon is anchored around the nameplate."] = true

-- New / reorganized sections (nameplates tab UX refresh)
L["Size & Position"] = true
L["Health Bar"] = true
L["Health Bar Background"] = true
L["Choose the background texture used behind the health bar fill."] = true
L["Power Bar Background"] = true
L["Choose the background texture used behind the power bar fill."] = true
L["Black"] = true
L["Same as Castbar"] = true
L["Elite Icon Vertical Offset"] = true
L["Fine-tune the elite/rare icon's vertical position."] = true
L["Target & Threat"] = true
L["Icons & Markers"] = true
L["Power Bar \226\128\148 Players Only"] = true
L["Always show the unit level next to the name."] = true
L["White border glow on the current target nameplate."] = true
L["Tank Mode"] = true
L["Inverts threat colors for a tank: green means you hold aggro, red means you lost it."] = true
L["DPS Mode"] = true
L["In combat, colors by threat for DPS: green = no aggro, yellow = transition, red = you have aggro."] = true
L["Keep all nameplates fully opaque when you have a target."] = true

L["Behavior"] = true
L["Retail-like Stacking"] = true
L["Simulates Retail's nameplate stacking for enemies."] = true
L["May increase CPU use with many visible nameplates."] = true
L["Depth Ordering"] = true
L["Order overlapping nameplates by depth."] = true
L["(Requires Allow Nameplate Overlap.)"] = true
L["Collider Width"] = true
L["Collider Height"] = true
L["Sets the width of the virtual collider centered on each nameplate used to detect overlaps."] = true
L["Sets the height of the virtual collider centered on each nameplate used to detect overlaps."] = true
L["Vertical Offset"] = true
L["Vertical offset baseline for Retail-like stacking."] = true
L["Freeze Mouseover"] = true
L["Keeps the hovered nameplate fixed while stacking updates around it."] = true
L["Disable in Open World"] = true
L["BG Healer Icon"] = true
L["BattleGroundHealers Compatibility"] = true
L["Keep BG healer marks attached to DragonUI nameplates."] = true
L["Override BattleGroundHealers icon position on DragonUI nameplates."] = true
L["This feature is available only when BattleGroundHealers is loaded."] = true
L["Enable Test Mode"] = true
L["Enable manual marking for BattleGroundHealers compatibility checks."] = true
L["Mark Target"] = true
L["Toggle BattleGroundHealers mark on your current target while test mode is enabled."] = true
L["Allow Nameplate Overlap"] = true
L["Addon Compatibility"] = true
L["Enable this if you use an external nameplate addon (PlateBuffs, Crosshairs, ...) that isn't detecting DragonUI's nameplates correctly."] = true
L["Nameplate Addon Compatibility"] = true
L["Stops overriding the nameplate's native transparency/visibility, which some external addons rely on to find their target. Non-target nameplates will dim like vanilla."] = true
L["Enable this if you use an addon (Icicle, ...) that attaches its own widgets to DragonUI's nameplate health bar."] = true
L["Nameplate Health Bar Compatibility"] = true
L["Hides the native health bar by fading its individual textures instead of the whole bar, for addons that attach widgets directly to it."] = true

L["Totem Click Padding"] = true
L["Extra clickable padding on totem nameplates (easier to click)."] = true
L["Clamp Target to Screen"] = true
L["Keep the target nameplate visible at the top of the screen. Extends WorldFrame height when enabled."] = "Keep the target nameplate visible on screen."
L["Clamp Bosses to Screen"] = true
L["Clamp Top Inset"] = true
L["Distance below the top edge where clamped nameplates stop."] = true
L["Bars"] = true
L["Clickbox"] = true
L["Clickbox Width Factor"] = true
L["Clickbox Height Factor"] = true
L["Show Clickbox"] = true
L["Displays the box selection space (clickbox) of nameplates."] = true


-- Nameplates: production-complete descriptions
L["Allow native nameplates to overlap. Retail-like Stacking enables this automatically because its custom stacking algorithm requires overlap."] = true
L["Color the glow and health bar by threat status (red = tanking, orange = losing, yellow = gaining)."] = true
L["Color the glow and health bar by threat status (orange = tanking, yellow = gaining or losing)."] = true
L["Keep hostile boss and world-boss nameplates visible at the top of the screen wherever they appear."] = true
L["Only apply Retail-like stacking inside party and raid instances. It remains disabled in the open world, battlegrounds, and arenas."] = true
L["Scales the nameplate clickbox relative to its original size. Changes made during combat are applied when combat ends."] = true
L["Show icons for recognized shaman totems. DragonUI uses localized spell names and automatically learns your own active totems."] = true

-- Search

L["Search settings..."] = true
L["Type to find a setting"] = true
L["No settings match '%s'."] = true
L["Showing top %d results. Type at least 3 characters for the full list."] = true
L["An ally carries dozens of auras, so you pick below what earns a slot."] = true
L["Debuffs on the Ally"] = true
L["Buffs the Ally Carries"] = true
L["Also Show These Spells"] = true
L["Listed spells always show, buff or debuff, on top of everything above."] = true

-- ============================================================================
-- PANELS TAB / GEAR SUMMARY
-- ============================================================================

L["Panels"] = true
L["Character"] = true
L["Stats Sidebar"] = true
L["The headline numbers above the stat categories."] = true
L["Show Item Level"] = true
L["Show the average item level of your equipped gear."] = true
L["Show GearScore"] = true
L["Show the GearScore of your equipped gear."] = true
L["Set which stat and which combat panel lead the list:"] = true
L["Highlight Main Stat"] = true
L["The attribute your class is built around."] = true
L["Auto (by class)"] = true
L["Combat Statistics"] = true
L["Which one leads the list: Melee, Ranged, or Spell."] = true
L["Opens the window without the micro menu."] = true
L["Toggle Pets & Mounts"] = true
L["Click, then press the key to bind. Press Escape to clear it."] = true
L["Key bindings cannot be changed in combat."] = true
L["Hide Model Controls"] = true
L["Hide the rotate, zoom and reset buttons over the character model."] = true
L["Keep the Reset Button"] = true
L["Leave the reset button on its own while the rest of the model controls stay hidden."] = true

-- World Map
L["World Map"] = true
L["Retail-style world map with breadcrumb navigation and a quest log side panel."] = true
L["Enable World Map"] = true
L["Apply the DragonUI reskin to the world map."] = true
L["Show Undiscovered Areas"] = true
L["Draw the map art of areas you have not explored yet, dimmed."] = true
L["Show Landmarks"] = true
L["Show Map Coordinates"] = true
L["Show your coordinates and the cursor's in the corner of the map."] = true
L["Show Zone Levels"] = true
L["Show the recommended level range next to zone names and instance pins."] = true
L["Fade Map While Moving"] = true
L["Dim the map while you move, unless the cursor is over it."] = true
L["Moving Map Alpha"] = true
L["How visible the map stays while you move."] = true
L["Show towns, flight points and other landmark pins on the map."] = true
L["Show Dungeon Entrances"] = true
L["Show dungeon and raid entrance pins on zone maps."] = true
L["Show Graveyards"] = true
L["Show graveyard pins on zone maps."] = true
L["Show Flight Points"] = true
L["Show flight master pins on zone maps."] = true
L["Show Inns"] = true
L["Show innkeeper pins on zone maps, marking the inn your hearthstone is set to."] = true

-- ============================================================================
-- LOW HP ALERT MODULE (added by DragonUI)
-- ============================================================================

L["Low HP Alert"] = true
L["Plays a sound and flashes the screen edges when your HP drops below the configured threshold."] = true
L["Enable Low HP Alert"] = true
L["Warning Sound (every 3 sec)"] = true
L["Plays a warning sound every 3 seconds while HP is below threshold."] = true
L["Screen Edge Flash"] = true
L["Flashes red at the edges of the screen while HP is below threshold."] = true
L["Flash Color"] = true
L["Use Class Color"] = true
L["Use your class color (e.g. orange for Druid, yellow for Rogue) instead of the custom color."] = true
L["Flash Opacity"] = true
L["Maximum opacity of the flash effect."] = true
L["Flash Extent"] = true
L["How far the flash extends from the screen edges toward the center, in pixels."] = true
L["HP Warning Threshold"] = true
L["Percentage of HP at which the warning triggers."] = true
L["Test Warning (3 sec)"] = true
L["Triggers a 3-second preview of the warning state to help you adjust the threshold."] = true

-- Talents
L["Talents"] = true
L["Retail-style talent window"] = true
L["Enable Talent Window"] = true
L["Replace Blizzard's talent and glyph window."] = true
L["Size of the talent window on top of your UI scale; 1.0 matches the other panels. It never grows past the screen."] = true
L["Show Glyph Names"] = true
L["Name each inscribed glyph beside its socket."] = true
L["Show Glyph Effects"] = true
L["List what your inscribed glyphs do beside the sockets."] = true

-- ============================================================================
-- SPELLBOOK MODULE
-- ============================================================================
L["Spellbook"] = true
L["Scale the spellbook window."] = true
L["Enable Spellbook"] = true
L["Enable the DragonUI spellbook module."] = true
L["Spellbook Content Scale"] = true
L["Scales the pages, cards and controls inside the spellbook; its frame keeps its size."] = true
L["Show Lower Rank Selector"] = true
L["Spell cards with lower ranks offer them through the selector chosen below."] = true
L["Lower rank selector"] = true
L["How a spell card offers its lower ranks: a menu under the icon or a side flyout."] = true
L["Menu under the icon"] = true
L["Side flyout"] = true
