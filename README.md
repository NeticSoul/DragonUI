# 🐉 DragonUI for 3.3.5a

<div align="center">

![Interface Version](https://img.shields.io/badge/Interface-30300-blue)
![WoW Version](https://img.shields.io/badge/WoW-3.3.5a-orange)
[![Version](https://img.shields.io/badge/Version-2.5-green)](https://github.com/NeticSoul/DragonUI/releases/tag/v2.5)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![Ko-fi](https://img.shields.io/badge/Support-Ko--fi-ff5e5b?logo=ko-fi)](https://ko-fi.com/neticsoul)
![Downloads](https://img.shields.io/github/downloads/NeticSoul/DragonUI/total?label=Downloads&color=%23a400ff)

**A modular, retail-inspired UI addon for World of Warcraft 3.3.5a (Wrath of the Lich King).**

</div>

---

<img width="1917" height="1054" alt="image" src="https://github.com/user-attachments/assets/dd45ed01-a35e-45fb-8426-897d29d35917" />
<details>
<summary><strong>See more screenshots (click to expand)</strong></summary>
<img width="1918" height="1054" alt="image" src="https://github.com/user-attachments/assets/d29e956a-4831-4a99-b1f3-4f3208a337e2" />
<img width="1917" height="1054" alt="image" src="https://github.com/user-attachments/assets/761d0315-ac4c-4aff-8e60-75beea91fdb1" />
<img width="1076" height="745" alt="image" src="https://github.com/user-attachments/assets/47a14b2f-f7ec-46ab-af35-e938d52d0e09" />
</details>

## 📥 Download

| Method | Link |
|--------|------|
| **Latest stable release** | [Download](https://github.com/NeticSoul/DragonUI/releases/download/v2.5/DragonUI-2.5.zip) |
| **Cutting-edge (main branch)** | [Download](https://github.com/NeticSoul/DragonUI/archive/refs/heads/main.zip) |

> The main branch always contains the most recent features and fixes. Releases are periodic snapshots that have been tested more thoroughly.

## 📦 Installation

<details>
<summary><strong>How to install (click to expand)</strong></summary>

1. Download the ZIP from one of the links above.
2. Extract it and open the folder.
3. Copy both `DragonUI` and `DragonUI_Options` to:

```text
World of Warcraft/Interface/AddOns/
```

4. Start the game and verify `DragonUI` and `DragonUI_Options` are enabled in the AddOns list.
5. Open settings with `/dui`.

**Clean install (reset settings):** Delete:

```text
WTF/Account/<YourAccount>/SavedVariables/DragonUI*
```

</details>

## ✨ Features

### Core UI

- 🧩 Modular system: enable or disable any major UI component independently.
- ⚙️ Custom configuration panel with profile support and per-module controls.
- ⌨️ Editor Mode: move and reposition nearly every UI element, with live X/Y coordinates and pixel-by-pixel position controls.
- 📋 Layout Presets: save, load, duplicate, delete, import, and export full UI layouts and addon settings using shareable export codes.
- 🌍 Localization for English, Spanish (ES/MX), German, Korean, Russian, Simplified Chinese, and Traditional Chinese.

### Frames And Bars

- 🎯 Action bars with configurable grid layouts, visibility rules, and button spacing.
- 💚 Unit frames for player, target, focus, party, pet, boss, ToT, and ToF, with elite dragon decoration, class portrait icons, and fat health bar mode.
- 🩹 Unit Frame Layers: heal prediction, absorb shields, and animated health loss overlays.
- 🔮 Castbars: custom castbars for player, target, and focus, with simple and detailed display modes, plus a built-in latency indicator on the player castbar.
- 📊 XP & Reputation bars with Dragonflight and RetailUI styles, independently movable.

### Visual Style

- 🖼️ HD textures for player frame (normal mode), target and focus name backgrounds. More HD assets coming in future updates.
- 🌙 Dark Mode with three intensity presets and custom color picker.
- ✨ Glow effects with separate combat and rest status controls and opacity slider.

### Inventory And Navigation

- 🎒 Auto-sort for bags and bank with slot locking, plus integrated module (Bagster) for unified inventory browsing.
- 🗺️ Custom Retail-style minimap (compatible with SexyMap).

### Utility And Quality Of Life

- 💬 Chat enhancements: style skins, fade sync, movable textbox with adjustable opacity, URL detection, chat copy, vanilla chat buttons with hover visibility, and `/tt` whisper command.
- 💎 Item quality borders, enhanced tooltips with class-colored borders, and range indicator.
- ⌨️ Easy-to-use keybinding mode on supported buttons.

Extensive customization available directly in-game through the configuration panel.

<!-- TODO: Add 2-3 screenshots here showing:
     1. The main UI in gameplay
     2. The options panel
     3. Editor mode with overlays visible
-->

## 🔧 Commands

| Command | Action |
|---------|--------|
| `/dragonui` or `/dui` | Open the configuration panel |
| `/dragonui edit` | Toggle Editor Mode |
| `/dragonui help` | Show all available commands |
| `/duicomp` | Compatibility diagnostics |
| `/sort` | Sort your bags |
| `/tt <message>` | Whisper your current target |
| `/rl` | Reload the UI |

## ⚠️ Known Issues

- Party/raid role icons (DPS, Healer, Tank) may be lost after `/reload` in Dungeon Finder groups.
- Single-line tooltips show text overlapping the health bar.
- Party and raid scenarios require further edge-case testing.
- Some third-party addon setups may require manual module disabling.
- Found a bug? [Open an issue](https://github.com/NeticSoul/DragonUI/issues).

## 🙏 Credits And References

DragonUI builds on original work, adapted code and ideas from these addon authors and projects. Each entry says what was used; the licenses are listed in [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md).

| Project | Author | Contribution |
|---------|--------|-------------|
| [Dragonflight UI (Classic)](https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI) | Karl-HeinzSchneider | Primary design reference; code snippets and textures adapted (MIT) |
| [New Era](https://www.curseforge.com/wow/addons/new-era-retail-ui-in-classic) | Ashgaroth | Upstream of DragonUI_NewEra; design reference for the talents, merchant, character panel, world map and retail nameplates; talent textures obtained via it (Blizzard art) |
| [DragonUI_NewEra](https://github.com/ghbset/DragonUI_NewEra) | ghbset, [LoneBrownie](https://github.com/LoneBrownie), contributors | Art and geometry reference for the character panel, talents, merchant, collections and world map; Blizzard textures obtained via it |
| [pretty_actionbar](https://github.com/s0h2x/pretty_actionbar) / [pretty_minimap](https://github.com/s0h2x/pretty_minimap) | s0h2x | Original inspiration for the action bars and minimap |
| [RetailUI](https://github.com/a3st/RetailUI) | a3st (Dmitriy) | Minimap, buff frame and API helper code and textures adapted (MIT) |
| [KPack](https://github.com/bkader/KPack) | bkader | Chat mods code adapted (MIT/X); source of the Combuctor code in Bagster and of the GearScoreLite formula |
| [Combuctor](https://github.com/Jaliborc) | Jason Greer (Tuller), João Cardoso (Jaliborc) | Bagster code adapted from Combuctor 4.2 via KPack (MIT) |
| [NotPlater](https://github.com/RichSteini/NotPlater) | RichSteini | Options panel spell-filter dialog code adapted (MIT) |
| [SexyMap](https://github.com/funkydude/SexyMap) | funkydude | Minimap border presets and rotation helper, used with permission |
| [GearScore / GearScoreLite](https://www.wowinterface.com/downloads/info14865-GearScoreLite.html) | Mirrikat45 | Character panel gear score formula |
| [BankStack](https://github.com/kemayo/wow-bankstack) | kemayo | Inspiration for the bag sort |
| [UnitFrameLayers](https://github.com/RomanSpector/UnitFrameLayers) | RomanSpector | Inspiration for the heal/absorb overlays; layer textures obtained via it (Blizzard art) |
| [SnowfallKeyPress](https://www.wowinterface.com/downloads/info15078-SnowfallKeyPress.html) | Dayn | Inspiration for casting on key down |
| [oGlow](https://github.com/haste) | haste | Item quality border concept |
| [ElvUI-WotLK](https://github.com/ElvUI-WotLK/) | ElvUI team | Pattern reference: load-on-demand options, slash commands, combat queue |
| [Quartz](https://github.com/Nevcairiel/Quartz) | Hendrik Leppkes | Latency indicator concept |
| [PentSec](https://github.com/PentSec) | PentSec | Collaborator: original drafts of the loot skin and world map modules |
| [CrimsonHollow](https://github.com/CrimsonHollow) | CrimsonHollow | Fat Health Bar contribution |
| [RovBot](https://github.com/RovxBot) | RovBot | Action bar grid/preset system |
| [Marrow](https://github.com/MarrowB83) | Marrow (Pexie) | Micro menu and unit frame contributions |
| [Andrew Kawula](https://github.com/akawula) | Andrew Kawula | Capture bar and faction progress bar fixes |
| [WYPanda](https://github.com/1825679767) | WYPanda | Chinese localization; minimap addon-button collector, LFG and party glow fixes |
| [Štefan](https://github.com/Stefan2102) | Štefan | Default profile for new characters, chat link tooltips, nameplate fixes |
| yetanotherneuron | yetanotherneuron (yan) | Player buff layout options and aura source tooltips; nameplate name fix |
| [migwynkriid](https://github.com/migwynkriid) | migwynkriid | 3D animated unit frame portraits, quest ability button in editor mode |
| [ZephZae](https://github.com/thezephyrsong) | ZephZae | AbsorbsMonitor zone and scaling fixes, bank stacking, collections micro button |
| Melquisdeq | Melquisdeq | UI warmup module; item level, unusable-item tint and quest starter icon fixes |
| [WillScarlettOhara](https://github.com/WillScarlettOhara) | WillScarlettOhara | Cast bar event matching fixes |
| [Ambitosis](https://github.com/Ambitosis) | Ambitosis | Questie compatibility fix |
| [perks](https://github.com/perks) | perks | Transmog cache fix |
| Chill Guy | Chill Guy | Always-hidden option for the micro menu and bag bar |
| [Raz0r](https://github.com/Raz0r1337) | Raz0r (St0ny) | German localization |
| [nadugi](https://github.com/nadugi) | nadugi | Korean localization |

Missing from the list? [Let me know](https://github.com/NeticSoul/DragonUI/issues).

## 💛 Special Thanks

- Everyone who tested early builds, reported bugs, and helped shape this addon.
- Translators who contributed localizations across different clients.
- The open-source addon community whose work made this project possible.

## 📜 License

DragonUI's own code is released under the [MIT License](LICENSE). Bundled libraries, fonts and code adapted from other projects keep their own licenses, and the SexyMap border presets are included with their author's permission - see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and [`LICENSES/`](LICENSES/) (copies of both ship inside the `DragonUI/` addon folder). World of Warcraft game artwork included in the addon (most textures under `DragonUI/Textures/`) is © Blizzard Entertainment, is not covered by the MIT License, and is included only for use with the game.

## 📎 Disclaimer

DragonUI is a free, fan-made addon. No content is sold and no in-game advantages are provided. Donations are entirely voluntary. Not affiliated with or endorsed by Blizzard Entertainment.

## ☕ Support The Project

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/neticsoul)

🪙 Bitcoin: `bc1q8yavz8857lzdfttas584892gf82y0u3wdfjz0a`

