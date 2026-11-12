# SD1 · critic, attempt 1

Head 7730f17. Checks 1-8 ✓. Score 8/8 → Accept.

1. Done against the brief: `layout.block(..., dress=)` → `build_map.py` writes `dress`; a station dresses named blocks
   only (`named_only()`); StationSurface leaves a dressed block's faces; TILE, cored or unloadable keep their box.
2. No contract broken: `StationSurface.mesh` gains an optional trailing `props`.
3. No hot path touched; `named_only()` duplicated once and cached; build-time work O(blocks).
4. Tests fail without the feature; colliders asserted unchanged; QA covers the unloadable fallback.
5. Rules in a plain resource and static builders; typed; no magic numbers or global state.
6. Look only; keeps Depot models out of Subway's generic kinds.
7. Small focused hunks, no lifetimes or scene edits.
8. In scope (Dev, Subway); note and record present; no wiki change (nothing visible yet).

Advisory: the cached `named_only()` copy would go stale if the source config were edited at runtime (harmless for a
loaded resource); `RoundSteps.boxes` takes the named-only config on a station (check when a round model is named).
