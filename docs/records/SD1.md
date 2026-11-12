# SD1 · Subway's dress path

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | ✓ | Accept 8/8 | – |

## Decisions

- **A station dresses only the blocks that name a model** (`PropDressConfig.named_only()`): Subway's kinds are generic
  (a cabinet is a ticket gate, a locker, a tool cart or a signal cabinet), so a kind alone never puts a Depot model in
  one of its boxes. A block names its model with `layout.block(..., dress="name")`; `build_map.py` writes it as the
  block's `dress`, and the model goes in `PropDressConfig.models` (its lay in `model_lays`, FIT by default).
- **StationSurface leaves a dressed block's faces to its model** (all lays but TILE, and a cored block keeps its
  box); a named model that won't load keeps its box, warned once. Colliders, nav and sight lines stay the boxes'.
- The room and spiral blocks (SM2's escalators and stairs) and a facing key for FIT (SM4's booths) are added by the
  threads that need them.

## Known issues left

- None.
