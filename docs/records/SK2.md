# SK2 · Stockade removed

**Review:** 1 attempt · critic pending · qa pending · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **Stockade is out of the game (owner, 2026-11-15: "Completely remove stockades map from game").** Gone: its row in
  `data/maps.md`, `data/maps/stockade.json`, `tools/stockade/`, its Match and loading pictures, `test_sk1_qa.gd` and
  its id in the map lists of six other tests, which now also check the catalogue has no Stockade row. `docs/DECISIONS.md`
  carries the ruling in place of the Bell tower one. SK1's record stays as history.
- **No models went with it.** Stockade was built from other maps' props and materials only, so nothing under
  `assets/models/` or `assets/textures/` was its own.
- **A last match played on Stockade** comes back as Depot: `MatchPicks.recall` keeps the last map only when the
  catalogue still has it, and the Match page passes over a pick with no card, as for every map removed before.

## Known issues left

- None.
