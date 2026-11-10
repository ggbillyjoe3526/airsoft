# UC1 · Remove the unused models and files

**Review:** 1 attempt · critic pending · qa pending · performance Pass

The owner, 2026-11-10: "Remove anything not needed." Every file in `assets/` was checked against what loads it (the
props' and the skyline's model tables, the map files' `dress` names, the configs' paths, the sounds' name patterns,
the textures each `.glb` embeds, the notices); everything else was in use.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | ✓ | pending | – |

## Decisions

- **Removed:** the six Kenney props no map names since Woodland's own models (WT1, WG2, WG4) and The Street's removal
  (SX1): `trunk`, `log`, `logstack`, `pine`, `tyre`, `truck`; their licence file; `tools/props/build_props.py`, which
  only built them; and Poly Haven's Concrete Floor 02, undrawn since DH1. Their config entries, the recipe test and
  the docs' rows went with them; the notices were regenerated.
- **`tools/woodland/build_map.py`** lost the trunk and CC0-log fallbacks no block reached; `woodland.json` rebuilds
  byte for byte.
- **Kept:** the street ambience (the Range's), every audio cue (they load by name pattern), the textures Godot
  extracts from the `.glb` models, and the dev tools that still build or picture a shipped model.

## Known issues left

- None.
