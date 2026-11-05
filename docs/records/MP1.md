# MP1 · New models in the UI's pictures

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Goal

The owner (2026-11-05): "When the new models are added will the images in the UI be updated to show them? If not make
sure all new models are shown." The Blender threads (BL4 to BL13) are replacing every model in parallel.

## Findings

- **Already live:** every replica, part and power source picture (Loadout, Switch Replica, Customise's turntable and
  part cards, the Armory, the level-up card) is drawn at run time by `ReplicaPictures` / `ReplicaTurntable` from
  `assets/models/replicas`, `replicaParts` and `powerSources`; nothing is baked, so a merged model shows at once.
- **Not live:** the smoke and flash icons (`GrenadeGlyph`, Loadout and HUD) were flat drawings; the crash screen's
  backdrop (`assets/ui/title-backdrop.jpg`) was a still with the old greybox rifle in it.
- **No UI picture:** figures, their gear and the first-person arms show only in a match, always live.

## Approach

- `ReplicaPictures.grenade_texture(kind, long_side)` draws a bomb from `assets/models/grenades/<smoke|flash>.glb` (BL9's
  path), its `Kind` material in `GrenadeView.BODY_COLOURS`, through the power sources' path (`_make_model`, shared).
- `GrenadeGlyph` takes that picture when it joins the tree (one `ReplicaPictures` child, only for a kind with a model,
  drawn once), sized to twice its size on screen (64 to 256 px), and falls back to the flat can with no model.
- `tests/unit/test_model_pictures.gd`: every model folder is pictured or listed as match-only; every replica, part
  folder, power and grenade model maps to something the UI pictures; every pool item has a picture; a bomb icon shows
  its model exactly when there is one. A new model, or folder, with no picture fails the build.
- The crash backdrop is Depot's Match picture, blurred: no replica in it to go stale (`docs/ASSETS.md`).

## Decisions

- **Model pictures on the HUD too,** not only the Loadout (owner: "make sure all new models are shown"); the flat can
  stays as the fallback. Easy to turn back to the flat icon on the HUD if it reads worse in play.
- **Bombs stand upright, seen from the side,** in the menus' light, as the power sources are.
- **Verified with stand-ins:** the gas bottle and spring copied in as smoke and flash (not committed) rendered sharp at
  96, 44, 40 and 28 px under xvfb.

## Known issues left

- None.
