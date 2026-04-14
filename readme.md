# DragonUI for WotLK 3.3.5a

### ⚠️ Old main backup branch.

---

![Interface Version](https://img.shields.io/badge/Interface-30300-blue)
![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-orange)
![Status](https://img.shields.io/badge/Status-Stable-green)

A personal project bringing Dragonflight UI aesthetics to WotLK 3.3.5a.

<img width="816" height="551" alt="{649C1BC5-978C-4852-B622-5ED11CE01A1F}" src="https://github.com/user-attachments/assets/54b8d8df-caf2-40e4-bb1e-5fec3a7f5039" />
<img width="816" height="551" alt="{1233C38B-B4C6-4D9F-BF7F-40165F6417E8}" src="https://github.com/user-attachments/assets/28b3ccfa-55a2-470f-8510-c6f5a484c063" />

## Features

*   **Modular System:** Enable or disable major UI modules individually, including Cast Bars,Mini Map, Action Bars, Micro Menu (with integrated bags), and the Cooldown system.
*   **Keybinding System:** Easily set or change your action bar keybinds by hovering over a button and pressing a key, no menus needed.
*   **Unit Frames:** Refactored Player, Target, Focus, and Party frames, each implemented as separate modules (including ToT/ToF)
*   **Micro Menu:** Two styles available (colored and grayscale), both with enhanced design, player portrait, faction-based PvP indicators, and integrated bags bar.
*   **Cast Bars:** Improved casting bars with modern styling.
*   **Action Bars:** Fully redesigned action bars.
*   **Cooldown System:** Standalone cooldown tracking module.
*   **Minimap:** Redesigned with better integration and customization options.
*   **Editor Mode:** Easy drag-and-drop system for repositioning frames and UI elements.
*   **Comprehensive Configuration:** Extensive in-game options panel with customization for positioning, scaling, and visual elements.
*   **Profile Management:** Save and switch between different UI configurations per character.
*   **Compatibility Manager:** Automatic detection and coordination with other addons for seamless integration.

## Installation

1. Download the latest `DragonUI.zip` from the [Releases page](https://github.com/NeticSoul/DragonUI/releases)
2. Extract the ZIP file to your `Interface\AddOns` folder
3. Open the configuration panel via ESC menu > DragonUI button or type `/dragonui`
4. Customize positioning, scaling, and visual elements to your preference

## Notes

This addon is a work in progress and may contain bugs. I'm working on it alone while still learning, so some parts of the code might look a bit wild, but that's the plan: to improve it over time.

If you're interested in helping develop or improve it, contributions are welcome! There's definitely room for optimization and fixes.

## Known Issues

- **Vehicle & Party UI Bugs:** Action bars, unit frames, and party frames may break, move, or display incorrectly when entering vehicles. All vehicle-related UI behavior still needs to be fixed.
- Other bugs are still present and will be polished over time.

## Credits

This project combines and adapts code from several sources:

- **[s0h2x](https://github.com/s0h2x)** – Two specific addons: one for action bars and another for minimap, which have been merged and integrated into DragonUI.
- **[KarlHeinz_Schneider - Dragonflight UI (Classic)](https://www.curseforge.com/wow/addons/dragonflight-ui-classic)** – Original addon from which many elements have been taken and backported/adapted to 3.3.5a, including the micro menu and other features built from scratch based on this design.
- **[a3st - RetailUI](https://github.com/a3st/RetailUI)** – Large portions of code are used as reference and directly integrated for UI elements and implementation approaches.

## Special Thanks

- **CromieCraft Community** – For helping test and provide feedback on various addon features.
- **Teknishun** – Special thanks for extensive testing and valuable feedback.
- **Project Epoch Community and Staff** – For their help and feedback during development and testing.
