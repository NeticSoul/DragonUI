# DragonUI checks

Run from the repository root with Lua 5.1:

```sh
lua5.1 tools/achievement_search_test.lua
lua5.1 tools/review_regression_test.lua
lua5.1 tools/window_positions_test.lua
python3 tools/recolour_grounds.py --check
```

The achievement test covers reward matching, translated type aliases, tier chains,
UI selection, cache reuse, debounced typing and invalidation while shown/hidden.
The regression test loads the production modules with Wrath-style API mocks and
covers position-preset round trips/rejection/rollback, vendor acknowledgements and
auto-repair sequencing, and mail capacity/timeout/COD/GM/close handling.
The texture check requires Pillow. These checks do not simulate protected frames or
prove server behavior in a real client.

## Client checks for 2.12.3

- Back up SavedVariables. Export/import a position preset, load it outside combat,
  and confirm detached/attached positions. A combat load must leave settings alone.
- Sell several grey stacks, including locked or uncached items. Compare inventory,
  money, buyback and printed totals; rejected requests must not count as sales.
  Check that auto-repair starts after selling and closing a vendor cancels its queue.
  Only cached, unlocked grey items with a positive vendor price are submitted;
  an unconfirmed request is skipped after five seconds without being retried. Other
  eligible stacks continue, and a notice asks you to check bags and buyback.
- With full bags, receive items that fit a partial stack or profession bag. A rejected
  attachment is skipped for this Open All pass so other attachments and gold can be
  collected. COD and GM mail must remain untouched. Reopen after freeing space.
- Search achievements quickly, earn an achievement, close/reopen the panel and try
  a non-English UI. English type keywords remain accepted alongside translated ones.

No live client/server deployment is performed by these scripts. This addon has no
wow-server manifest pin; deliver both addon folders from the reviewed release.

## Client checks for 2.12.4 movable windows

Drag a title bar on character, quest log/dialog, merchant, mail, guild, collections,
professions, talents, spellbook, bank, friends, achievements, trainer, auction house,
trade, inspect, dungeon finder and PvP windows. Stock individual bags are saved by
bag ID, not by the pooled ContainerFrame number. Bagster, world map and loot keep
their existing movement/persistence systems.

- Verify positions survive close/reopen and reload, including late-loaded windows.
- Open another panel while one is moved: it should stay where placed and still
  close normally through its button, Esc or the underlying NPC interaction.
- Change UI scale/resolution and confirm windows remain reachable.
- Exercise spellbook and talents scale changes, drag/drop state and their existing
  click catchers. Professions' drag area follows the scaled presentation while
  moving its original TradeSkillFrame host.
- Attempt a drag in combat and enter combat mid-drag. No protected positioning
  should run until combat ends.
- Alt-right-click a new title area to reset that window. `/dui windows reset`
  clears the new position store, including unopened windows. Existing Bagster/map/
  loot settings retain their own resets. Verify switching/resetting profiles.

The mock suite checks movement lifecycle, saved-coordinate restoration after
layout, effective scale conversion, on-screen clamping, protected-frame guards,
pooled bag IDs, profile changes and resets. Real-client secure panel behavior,
third-party window movers and title-area hit testing remain client validation tasks.
