# DragonUI checks

Run from the repository root with Lua 5.1:

```sh
lua5.1 tools/achievement_search_test.lua
lua5.1 tools/review_regression_test.lua
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
  an unconfirmed request stops the pass after five seconds without being retried.
- With full bags, receive items that fit a partial stack or profession bag. A rejected
  attachment is skipped for this Open All pass so other attachments and gold can be
  collected. COD and GM mail must remain untouched. Reopen after freeing space.
- Search achievements quickly, earn an achievement, close/reopen the panel and try
  a non-English UI. English type keywords remain accepted alongside translated ones.

No live client/server deployment is performed by these scripts. This addon has no
wow-server manifest pin; deliver both addon folders from the reviewed release.
