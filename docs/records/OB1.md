# OB1 · One BB on a magazine, the pistols square at the hip

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

The owner's 0.1 Beta 2 playtest, items 11 ("3d models of magazines show 3 bbs at the top of the magazines. There
should only be 1 visible bb") and 17 ("pistol angle at hip is slightly too far left. move it slightly to the right to
better match the same angle as the rifle"). No task block.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | Opus 5.5 (build thread) | ✓ | 7/8 Retry | The one BB on the replicas' own magazines still the old faceted ball |
| 2026-11-17 | 2 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **One BB on every magazine, the Pump Shotgun's shell too.** It showed three side by side (one a barrel); the owner
  asked for one, so the middle one stays.
- **The BB kept is the one at the lips** (the top, front one), where the next shot feeds from.
- **The one BB is a true ball everywhere.** The replicas' own magazines turn it 24 sides in 12 bands
  (REPLICA_BB_ROUND); the magazine parts spend the dropped BBs' triangles on theirs (Hi-Cap 54 sides, Low-Cap 58,
  Extended 34), so each part keeps over 90 % of its 10,000-triangle budget.
- **The pistols lie square at the hip, exactly at the rifles' angle** (ViewModelConfig.hip_turn now empty; HA2 had
  turned them 0.15 rad in). The muzzle points at the crosshair as a rifle's does. If the owner finds it too far right
  now, a turn of about 0.05 rad is the half-way setting.
- **glb_images.py keeps a parts file's wear mask name** when a later script reads the file back and writes it again
  (figure_parts.py after magazines.py wrote `aeg_aeg_wear.png`).

## Known issues left

- None. The owner checks the pistols' angle in play (beta 2 checklist N28).
