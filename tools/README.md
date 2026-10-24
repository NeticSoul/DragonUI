# DragonUI checks

Run from the repository root with Lua 5.1:

```sh
lua5.1 tools/achievement_search_test.lua
lua5.1 tools/bartender_handoff_test.lua
lua5.1 tools/keybinding_search_test.lua
lua5.1 tools/review_regression_test.lua
lua5.1 tools/window_positions_test.lua
python3 tools/recolour_grounds.py --check
python3 tools/link_icon_bubble.py --check
```

The Bartender4 hand-off test covers switching the bar modules off while Bartender4 is loaded, keeping Bartender4's micro menu, bag bar and XP/Rep bars off without changing its settings, the once-per-change login line, restoring only the handed modules on a later load (never mid-session), and the opt-out. It does not load mainbars.lua or noop.lua, whose Bartender4 paths need a game client.
The key binding search test covers filtering by command name and key, kept section headers, scrolling the filtered list, selection highlight, deselect on focus and reset on close.
The achievement test covers reward matching, translated type aliases, tier chains,
UI selection, cache reuse, debounced typing and invalidation while shown/hidden.
The regression test loads the production modules with Wrath-style API mocks and
covers position-preset round trips/rejection/rollback, vendor acknowledgements and
auto-repair sequencing, and mail capacity/timeout/COD/GM/close handling.
The texture check requires Pillow. These checks do not simulate protected frames or
prove server behavior in a real client.

Not yet checked in a game client: the Bartender4 hand-off, the Key Bindings search box, position presets and window dragging across the panels, grey-item
auto-sell and auto-repair, Open All with full bags, achievement search, and the unit-frame styles
and combo-point modes after the last upstream merge. Also not checked: portrait-off unit frames
(beta) with their decorations and icons, /reload in an LFG party, tooltip sharing with other
addons, empty-loot auto-hide, large alt-gold totals, and Mind Sear / Volley ticks.

After merging upstream, `python3 tools/recolour_grounds.py --check` says whether `ui-background-rock`
and `ui-background-marble` need their warm brown recolour regenerated.
