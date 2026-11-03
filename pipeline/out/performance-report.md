# Performance report: UF2 (9965b76)

Verdict: **Pass**. No `--perf` match run: the diff touches no in-match code, only the Loadout's card build. Judged by
reading the diff against the targets (no baseline yet).

- `game/ui/loadout_gear.gd`: the two `mouse_filter` sets run once per card at build time, not per frame; no allocation.
- Removing `_double_click` and its `card.gui_input` connection drops a bound Callable per card and a handler that ran
  on every mouse event over the card. Nothing left connected or unfreed.
- `customise_requested` is still emitted by CUSTOMISE and connected in `loadout_page.gd`.
- `tests/unit/test_uf2_clicks.gd` is test-only and does not ship.

No blocking or advisory findings.

## Part 2: skip grace (ee0eb5a)

Verdict: **Pass**. No `--perf` run: the change is one float add per frame (no baseline yet; judged by reading the diff).

- `game/play/play_session.gd:1418`: `_follow_skip(delta)` does a float add, a compare and two bool ops per frame; no
  Array, String, Callable or node allocation. `_out_for` (line 216) is a plain float; nothing to free or disconnect.
- `set_skip_hint(ready)` is called each frame as before; its cost is unchanged from Part 1's baseline behaviour.
- `skip_grace` is a typed `@export` on `PlayTuning` read from the cached `_play`; no per-frame load.
- The count runs in `_process`, so skip's own fast tick loop does not touch it (`can` is false while `_skipping`).

No blocking or advisory findings.
