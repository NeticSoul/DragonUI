# Third-Party Notices

DragonUI's own code is released under the MIT License (`LICENSE` at the repository root,
`LICENSE.txt` inside the `DragonUI` addon folder). This file lists everything shipped in the two
addon folders that is not DragonUI's own work, or that is under other terms.

Paths are relative to the repository root, except `LICENSES/`, which is the folder next to this
file (`DragonUI/LICENSES/`). Users install only the `DragonUI/` and `DragonUI_Options/` folders, so
this file and `LICENSES/` live inside `DragonUI/` to ship with the addon, and
`DragonUI_Options/LICENSES/` holds the texts that apply to that folder.

## Blizzard Entertainment artwork and game data

Most textures under `DragonUI/Textures/` are World of Warcraft user-interface artwork, taken from
the 3.3.5a client or from later retail and Classic clients. That artwork is © Blizzard
Entertainment, Inc. It is **not** covered by DragonUI's MIT License, nor by the MIT licenses of the
projects named in this file, and it is included only so that the addon can display it inside
World of Warcraft. The same applies to any World of Warcraft artwork under
`DragonUI_Options/Textures/`. A texture that DragonUI or another project cropped, recoloured,
re-encoded, repacked or pre-rendered is still Blizzard's artwork.

The projects named below (DragonflightUI, DragonUI_NewEra and its upstream New Era by Ashgaroth,
pretty_actionbar and pretty_minimap by s0h2x, RetailUI, UnitFrameLayers) are the addons the files
were obtained via. They are credited as conduits, not as the authors of the art.

| Folder under `DragonUI/Textures/` | Obtained via |
|---|---|
| `ActionBars/` | pretty_actionbar (s0h2x); some sheets carry his small repacking edits, which leave them Blizzard's art; `uiactionbar2x_forever` cut from WoW Forever's end-cap sheet (`uiactionbar2xc60`) |
| `Bags/` | DragonflightUI (`bagborder2`, `bagslotCutout`, `bagsitemslot2x`, `bagsitembankslot2x`), pretty_actionbar (`bagslots2x`, `bagslots2key`); `INV_Misc_Bag_08_round` is the retail bag icon, cropped round |
| `Castbar/`, `Editmode/`, `Reputation/` | DragonflightUI |
| `CharacterPanel/` | DragonUI_NewEra; `resistanceicons.tga` is cut from 3.3.5a client art |
| `ClassIcons/` | retail class icon art (source file not recorded) |
| `Coins/` | DragonflightUI (`commoncoinbox`, `commoncurrencybox`); the coins are retail art |
| `Collections/` | see [Collections artwork](#collections-artwork) |
| `Merchant/` | DragonUI_NewEra; `emptyslot.blp` is the 3.3.5a client's own |
| `Micromenu/` | DragonflightUI, pretty_actionbar |
| `Minimap/` | pretty_minimap (s0h2x), RetailUI (`Calendar`, `GuildBanner`, `MinimapBorder`); `collector_toggle.tga` is cropped from the retail minimap border in `UI/Minimap.blp`; `forever_*` cut from WoW Forever's minimap sheets (`uiminimap2xc60`, `uiminimapmaskgeneralc60`) |
| `Nameplates/Retail/` | see [Retail nameplate artwork](#retail-nameplate-artwork) |
| `Nameplates/Totem/` | 3.3.5a spell icons with a new frame |
| `NewLevelUp/` | retail level-up art |
| `Quest/` | New Era by Ashgaroth (retail quest-giver icons); `repeatablequesticon` is retail's `DailyActiveQuestIcon` |
| `Spellbook/` | retail spellbook art contributed by PentSec (pull request #485); cropped to the pieces the book draws and re-encoded (`spellbook-ribbon` kept uncompressed) |
| `Talents/` | DragonUI_NewEra and New Era by Ashgaroth; `Artifact/` holds Legion-era retail art |
| `UI/` | RetailUI atlases (`UnitFrame`, `MicroMenu`, `Minimap`, `CastingBar`, `QuestTracker`, `BagSlotsKey`, `CollapseButton`); DragonflightUI and DragonUI_NewEra retail frame chrome; a few 3.3.5a client files |
| `UnitFrames/` | DragonflightUI (`HD/` is its `Unitframe2x` art, re-cut into BACKGROUND/BORDER pieces; `HD/Target-NameStrip` is re-cut from `Target/UIUnitFrame2x_PTR`); `Layers/` via UnitFrameLayers (RomanSpector); `Player/ClassOverlayDeathKnightRunes`, `Player/LFGRoleIcons`, `Player/PlayerRestFlipbook` and `uiunitframeboss2x` via RetailUI; `pvpforever` cut from WoW Forever's unit frame sheet (`uiunitframe2xc60`), and `Forever/` re-cut from that same sheet into BACKGROUND/BORDER pieces plus its level circle and skull (`Level`); `Forever/Party-*` re-cut the same way from WoW Forever's party sheet (`partyc60`, 1x, upscaled); `HD/Party-InCombat` is the retail unit frame sheet's (`uiunitframe2x`) ToT aggro glow; `Forever/uiunitframeboss2x` is WoW Forever's elite dragon sheet (`uiunitframebossc602x`), re-encoded; `Forever/Player-Status`, `Forever/Target-InCombat` and `Forever/Target-Type` (tinted) are DragonflightUI's `Unitframe2x` art, `Forever/Player-InCombat` and `Forever/Player-CombatIcon` are cut from the retail unit frame sheet (`uiunitframe2x`) that WoW Forever ships; `PvP/` is that sheet's PvP art, laid out like Blizzard's `UI-PVP-*` and `UI-Group-PVP-*` icons; `Icons/StatusIcons` gathers that sheet's leader, guide and group-tab caps, the group tab's middle (`groupindicatormid-2x`), the retail tiny role icons (`roleicon-tiny-sheet`) and WoW Forever's group finder leader and role icons (`groupfinder-c60-2x`) |
| `WorldMap/` | see [World map artwork](#world-map-artwork) |
| `XP/` | DragonflightUI; `uiexperiencebar.blp` via pretty_actionbar / RetailUI |

Data tables generated from the World of Warcraft client's database (DBC) files are game data
© Blizzard Entertainment and are not covered by DragonUI's MIT License:
`DragonUI/modules/worldmap/fogdata.lua`, `entrancedata.lua`, `flightpointdata.lua`,
`graveyarddata.lua`, and `DragonUI/data/aura_durations.lua`, `companion_traits.lua`. The inn
positions in `DragonUI/modules/worldmap/inndata.lua` are derived from AzerothCore's world-database
spawn data together with the client's map data, and the class trainer lists in
`DragonUI/modules/spellbook/trainerdata.lua` from AzerothCore's trainer tables together with the
client's spell data.

World of Warcraft, Warcraft and Blizzard Entertainment are trademarks or registered trademarks of
Blizzard Entertainment, Inc. DragonUI is a free, fan-made addon and is not affiliated with or
endorsed by Blizzard Entertainment.

## Ace3 and CallbackHandler-1.0

Copyright (c) 2007, Ace3 Development Team. BSD-style license with an extra clause that forbids
redistributing a stand-alone version without written permission. DragonUI only embeds these
libraries, loaded from its own TOC files, which the license allows. Full text:
[LICENSES/Ace3.txt](LICENSES/Ace3.txt).

- `DragonUI/libs/`: AceAddon-3.0, AceComm-3.0, AceConsole-3.0, AceDB-3.0, AceEvent-3.0,
  AceLocale-3.0, AceSerializer-3.0, AceTimer-3.0, CallbackHandler-1.0.
- `DragonUI_Options/libs/`: AceConfig-3.0, AceGUI-3.0, CallbackHandler-1.0.

CallbackHandler-1.0 is published in the Ace3 repository and is covered by the same text.
`DragonUI/libs/AceLocale-3.0/AceLocale-3.0-DragonUI.lua` is DragonUI's fork of AceLocale-3.0 and
remains under the Ace3 license.

## GPL-2.0-or-later: AbsorbsMonitor-1.0

`DragonUI/libs/AbsorbsMonitor-1.0/` is Copyright (C) 2010 Philipp Schmidt, licensed under the GNU
General Public License, version 2 or (at your option) any later version. The DragonUI contributors
modified it in 2026 (zone modifiers, absorb scaling, Spellsteal fix); the change is noted at the top
of the file and recorded in git history. The full license text is in
[LICENSES/GPL-2.0.txt](LICENSES/GPL-2.0.txt) and in the library folder
(`DragonUI/libs/AbsorbsMonitor-1.0/GPL-2.0.txt`).

This library stays under the GPL: DragonUI's MIT License does not apply to it, and you may
redistribute or modify it only under the GPL. DragonUI's own code remains available under the MIT
License, which is compatible with the GPL. If you redistribute DragonUI with this library included,
you must also meet the GPL's conditions for the library.

## LibHealComm-4.0

`DragonUI/libs/LibHealComm-4.0/` (revision 66) is © its authors (Shadowed; maintained on WowAce by
Azilroka). Its WowAce/CurseForge project page lists the license as "All Rights Reserved"; the
library is published there for embedding in addons, and DragonUI embeds it for that purpose. The
file carries no license header. DragonUI applies two local patches:

- talent entries without a recorded point count start at zero, which fixes a nil error during
  Lesser Healing Wave (2026-05-02);
- the UNIT_AURA handler ignores events that arrive without a unit (2026-07-08).

## SexyMap border presets (used with permission)

The minimap decoration presets and the texture-rotation helper in
`DragonUI/modules/minimap_decorations.lua` are adapted from SexyMap by funkydude (Funkeh), an
"All Rights Reserved" project; they came from an older public WotLK version of SexyMap. The author
gave DragonUI permission to keep using and distributing them on 2026-09-27 (Discord). This material
is included with that permission only and is not covered by DragonUI's MIT license; the rest of the
file is DragonUI's own code under MIT.

## zlib License: LibDeflate

`DragonUI/libs/LibDeflate/LibDeflate.lua` (1.0.2) is Copyright (C) 2018-2020 Haoqian He, licensed
under the zlib License. The license is kept in the file's own header; the file is unmodified.

## Public-domain libraries

- LibStub (`DragonUI/libs/LibStub/`, `DragonUI_Options/libs/LibStub/`): placed in the public domain.
- ChatThrottleLib (`DragonUI/libs/AceComm-3.0/ChatThrottleLib.lua`,
  `DragonUI/libs/LibHealComm-4.0/ChatThrottleLib.lua`): public domain.
- LibKeyBound-1.0 (`DragonUI/libs/LibKeyBound-1.0/`): public domain (Gello, Maul, Tuller,
  Toadkiller); DragonUI has made small local changes to it.

## MIT License: RetailUI

Copyright (c) 2024 Dmitriy (a3st), https://github.com/a3st/RetailUI. Full text:
[LICENSES/MIT-RetailUI.txt](LICENSES/MIT-RetailUI.txt).

- Code adapted from RetailUI: `DragonUI/modules/minimap.lua`, `DragonUI/modules/buff_frame.lua`,
  `DragonUI/core/api.lua`.
- Textures taken from RetailUI: `DragonUI/Textures/UI/UnitFrame.blp`, `MicroMenu.blp`,
  `Minimap.blp`, `CastingBar.blp`, `QuestTracker.BLP`, `BagSlotsKey.blp`, `CollapseButton.blp`;
  `DragonUI/Textures/Minimap/Calendar.blp`, `GuildBanner.blp`, `MinimapBorder.blp`;
  `DragonUI/Textures/UnitFrames/Player/ClassOverlayDeathKnightRunes.BLP` (and its recolour
  `ClassOverlayDeathKnightRunes_Purple.blp`), `LFGRoleIcons.blp`, `PlayerRestFlipbook.blp`;
  `DragonUI/Textures/UnitFrames/uiunitframeboss2x.blp`;
  `DragonUI/Textures/UnitFrames/Target/NameBackground.tga`.

The underlying artwork is © Blizzard Entertainment (see above); RetailUI's MIT License covers only
RetailUI's own contribution.

## MIT License: Combuctor (via KPack)

Copyright (c) 2010 Jason Greer (Tuller) and João Cardoso (Jaliborc). Combuctor's repository carried
an MIT License from September 2010 to September 2012; the file holds its December 2011 text. The
code reached DragonUI through KPack's Combuctor module. Full text:
[LICENSES/MIT-Combuctor.txt](LICENSES/MIT-Combuctor.txt).

Files containing adapted code: the Bagster module in `DragonUI/modules/bagster/`, chiefly
`bagster.lua`, `bagster_classes.lua`, `bagster_frame.lua`, `bagster_data.lua`,
`bagster_system.lua` and `bagster.xml`.

## MIT License: KPack ChatMods

KPack by Kader (bkader), https://github.com/bkader/KPack, which declares "MIT/X" in its TOC.
Full text and details: [LICENSES/MIT-KPack.txt](LICENSES/MIT-KPack.txt).

File containing adapted code: `DragonUI/modules/chatmods.lua`.

## MIT License: NotPlater

Copyright (c) 2023 RichSteini, https://github.com/RichSteini/NotPlater (the code came from
NotPlater 3.2.4, whose LICENSE is this MIT text). Full text:
[LICENSES/MIT-NotPlater.txt](LICENSES/MIT-NotPlater.txt).

File containing adapted code: `DragonUI_Options/panel/controls.lua` (the spell-filter prompt popup
and the spell-filter import/export dialog, with the code that opens it).

## MIT License: DragonflightUI

Copyright (c) 2022 Karl-HeinzSchneider, https://github.com/Karl-HeinzSchneider/WoW-DragonflightUI.
Full text: [LICENSES/MIT-DragonflightUI.txt](LICENSES/MIT-DragonflightUI.txt).

- Textures and texture coordinates taken from DragonflightUI: `DragonUI/Textures/UnitFrames/`
  (except `Layers/` and the RetailUI files listed above), `Castbar/`, `Reputation/`, `XP/` (except
  `uiexperiencebar.blp`), `Editmode/`, `Coins/commoncoinbox.blp`, `Coins/commoncurrencybox.blp`,
  `Bags/bagborder2.blp`, `Bags/bagslotCutout.blp`, `Bags/bagsitemslot2x.blp`,
  `Bags/bagsitembankslot2x.blp`, `Micromenu/uimicromenu2x.blp`, `Micromenu/Atlas/uimicromenu2x.blp`,
  `Micromenu/micropvp.blp`, retail frame chrome in `UI/` (`uiframemetal*`, `uiframetabs`,
  `redbutton*`, `ui-background-rock`, `uiframeinner`, `uiframe-diamondmetal*`, shared with
  DragonUI_NewEra), `Collections/IconFrameGold.tga` (cut from DragonflightUI's Spellbook-Parts
  sheet and resampled), `Nameplates/Retail/castbar-atlas.blp`, `WorldMap/questbg-parchment.blp`.
- Small code snippets adapted from DragonflightUI: `DragonUI/core/api.lua` (nine-slice helper),
  `DragonUI/modules/micromenu.lua`, `DragonUI/modules/bagster/bagster_classes.lua`.

DragonflightUI's textures are retail World of Warcraft art © Blizzard Entertainment (see above);
its MIT License covers only Karl-Heinz Schneider's own contribution.

## Collections artwork

The retail Mount and Pet Journal textures under `DragonUI/Textures/Collections/`
(`MountJournal-BG.blp`, `MountJournalIcons.blp`, `FavoritesIcon.blp`, `ListButtons.blp`,
`MountPortrait.tga`, `PetPortrait.tga`) are retail art © Blizzard Entertainment. They were obtained
via DragonUI_NewEra; ezCollections by ZEUStiger ships the same art at Blizzard's own paths.
`IconFrameGold.tga` comes from DragonflightUI (see above), and `UI-Searchbox-Icon.blp` is the 3.3.5a
client's own search icon.

## World map artwork

The textures under `DragonUI/Textures/WorldMap/` (breadcrumb bar, quest log panel, quest type
icons, quest page parchment, experience icon, filter button, landmark icons, side panel toggle) are
cut from retail's own sheets (© Blizzard Entertainment) and repacked power-of-two for 3.3.5a. They
were obtained via DragonUI_NewEra, the downport of Ashgaroth's New Era, through a world map module
contributed by PentSec; `questbg-parchment.blp` is the same file DragonflightUI ships. The
magnifier on the filter button is the client's own `Interface\Minimap\Tracking\None`
(© Blizzard Entertainment), composited over that sheet's disc.

## Retail nameplate artwork

The textures under `DragonUI/Textures/Nameplates/Retail/` (health bar capsule and fill, selection
border, deselected overlay, aggro flare, cast bar frame and fills) are cut from retail's own
nameplate and casting bar sheets (© Blizzard Entertainment), as used by New Era by Ashgaroth, the
Classic Era addon that DragonUI_NewEra downports. The bar fills are repacked power-of-two for
3.3.5a, and the aggro flare has its mask baked into the alpha. `castbar-atlas.blp` is the same file
DragonflightUI ships as its casting bar sheet, and `nameplate-bake.blp` is DragonUI's own
pre-render of those retail sheets.

## Bundled fonts

| Font | Path | License | License file |
|---|---|---|---|
| Expressway Free, version 2.100 (© 2005 Ray Larabie / Typodermic; "Expressway" is a trademark of Typodermic) | `DragonUI/Fonts/expressway.ttf` | Typodermic Freeware Fonts End User License Agreement | [LICENSES/Typodermic-EULA.txt](LICENSES/Typodermic-EULA.txt) |
| PT Sans Narrow Bold (© 2009-2010 ParaType Ltd; Reserved Font Names "PT Sans", "PT Serif", "ParaType") | `DragonUI_Options/fonts/PTSansNarrow.ttf` | SIL Open Font License 1.1 | [LICENSES/OFL-1.1.txt](LICENSES/OFL-1.1.txt) |

Both font files are shipped unmodified. The font's own notice says "This font is freeware. Read
attached text file for details"; `LICENSES/Typodermic-EULA.txt` is a word-for-word plain-text copy of
that attached file, `Typodermic Freeware EULA.html` (dated 2004-09-30), as Typodermic distributed it
with Expressway Free in its official download (`typodermic.com/free/expressway_free.zip`, archived
2005-2007). PT Sans Narrow also carries the full OFL text inside the font file itself.
