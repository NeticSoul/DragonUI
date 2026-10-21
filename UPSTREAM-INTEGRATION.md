# Upstream integration — October 19, 2026

Evermore base: `32e94f0`. Upstream: NeticSoul/DragonUI main at
`4e3003ca51a945f4692ff757be52b6b2cdc9c717` (13 commits after common ancestor `7f49f12`).
Both addon TOCs identify this integration as Evermore version 2.12.2.

## Conflicts and compatibility

- Resolved the module-loader conflict by retaining both Evermore's `servercurrency.lua`
  and upstream's `itemownership.lua`, before the character panel and Bagster.
- Shared files merged automatically: core API, database defaults, English strings,
  panel options and README. Evermore's server currency defaults, guild/professions
  integrations, achievement search, Postal mail adjustments and brown window grounds
  are retained. Automatic merging is not proof of in-client compatibility.
- Item ownership is a second inventory cache alongside Bagster. It counts bags,
  bank and equipment per character/realm; it does not include Evermore server-held
  currencies, account reagent storage or guild bank balances. It stays disabled by
  default. Enabling it alongside another ownership tooltip addon may duplicate lines.
- Upstream replaces the Forever target combo-point gem arc with small orbs and changes
  combo-point visibility/layout. This is an intentional imported visual change,
  including for existing profiles; verify both frame styles and detached editor layouts.
- Portrait-off unit frames are beta and default off. Verify player/target/focus/pet/
  party layouts, decorations, text, PvP/LFG/master-looter/resting icons and combat toggles.
- Empty-loot auto-hide stays off by default. Spell IDs use the existing spell-ID option.
- Upstream's party-role refresh, large gold formatting, channel ticks and spell-link
  fixes are included, together with the contributor follow-up fixes.

## Validation and release

Run Lua 5.1 syntax checks (accepting UTF-8 BOMs as in WoW), the existing
`tools/achievement_search_test.lua`, XML/TOC reference checks, and
`python3 tools/recolour_grounds.py --check` and `python3 tools/link_icon_bubble.py --check`. Record results in the integration PR.

Client validation remains required: login/reload in an LFG party, combat and edit mode,
all unit-frame styles and combo-point modes, tooltip sharing with other addons,
bank/cache updates, loot auto-hide, large alt-gold totals and Mind Sear/Volley ticks.
No client deployment or live-server verification is implied by a merged PR.

This addon has no server manifest row. Release delivery consists of the reviewed
addon branch/version and copying both `DragonUI` and `DragonUI_Options` to the client
(or updating their launcher package); no server module pin is required.
