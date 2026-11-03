# Performance report: UF2 (9965b76)

Verdict: **Pass**. No `--perf` match run: the diff touches no in-match code, only the Loadout's card build. Judged by
reading the diff against the targets (no baseline yet).

- `game/ui/loadout_gear.gd`: the two `mouse_filter` sets run once per card at build time, not per frame; no allocation.
- Removing `_double_click` and its `card.gui_input` connection drops a bound Callable per card and a handler that ran
  on every mouse event over the card. Nothing left connected or unfreed.
- `customise_requested` is still emitted by CUSTOMISE and connected in `loadout_page.gd`.
- `tests/unit/test_uf2_clicks.gd` is test-only and does not ship.

No blocking or advisory findings.
