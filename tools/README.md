# DragonUI checks

Run from the repository root with Lua 5.1:

```sh
lua5.1 tools/achievement_search_test.lua
lua5.1 tools/review_regression_test.lua
lua5.1 tools/window_positions_test.lua
python3 tools/recolour_grounds.py --check
python3 tools/link_icon_bubble.py --check
```

The achievement test covers reward matching, translated type aliases, tier chains,
UI selection, cache reuse, debounced typing and invalidation while shown/hidden.
The regression test loads the production modules with Wrath-style API mocks and
covers position-preset round trips/rejection/rollback, vendor acknowledgements and
auto-repair sequencing, and mail capacity/timeout/COD/GM/close handling.
The texture check requires Pillow. These checks do not simulate protected frames or
prove server behavior in a real client.

Not yet checked in a game client: position presets and window dragging across the panels, grey-item
auto-sell and auto-repair, Open All with full bags, achievement search, and the unit-frame styles
and combo-point modes after the last upstream merge.

After merging upstream, `python3 tools/recolour_grounds.py --check` says whether `ui-background-rock`
and `ui-background-marble` need their warm brown recolour regenerated.
