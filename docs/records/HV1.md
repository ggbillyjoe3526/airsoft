# HV1 · The hit area fitted to the drawn figure

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (hits thread) | – | – | – |

## The ask

The owner, 2026-11-03: "I seem to have an issue with hit registration. I'm sure I'm hitting the target but it's not
registering. Can you make sure this works properly?"

## What was wrong

BBs were fine: every tick tests the BB's whole path (swept, so no tunnelling even at a sniper spring's speed), and the
BB, the shot and the hit all run on the same 60 Hz tick. The hit area was not: it was still Hitbox's built-in volume, a
capsule figure that never followed the rigged figure's animation (FI7 measured it and left it to HV1). A crouched
figure kneels low and forward while the volume stood squashed upright, so a BB on what you saw missed 28 % of the
crouched figure, 36 % crouch-walking, 25 % running, 26 % vaulting and 18 % aiming 60° up or down, and thin air beside
it counted on 19 to 37 %.

## What changed

1. **HitFit** (`game/sim/hit_fit.gd`, `game/config/hit_fit.tres`): the human's skeleton posed by its own animation
   graph, baked by `tools/hit_fit_bake.gd` (`HitFitBaker`): each gait and crouch blend space point's clip at 24 phases
   of the walk cycle, still standing and crouched, 7 jump and 12 vault samples (the hips' place and turn and each leg
   bone's turn), and the upper body in the hips' frame for the rifle's and the pistol's aim down, level and up,
   holstered and holstered sprinting. 55 KB.
2. **Hitbox.build_volume** blends them as the graph does: the gait space by its own triangles and barycentric weights
   (the nearest edge outside them), the crouch space linearly, the crouch by its amount, each turn as weighted steps
   from its rest (AnimationMixer's blend); poses the legs down from the hips; puts the upper body on them; then
   FigureBend's crouch limit, lean and aim lean. The capsules hang on the joints: a head sphere, a torso of four
   capsules (side by side for the width, front and back for the plate carrier's pouches and the pack), the hips, and
   each leg's thigh, shin and boot. Their shapes are `HitConfig.fit_*`, tuned by `tools/hit_fit_tune.gd` against the
   drawn figure. The built-in volume stays for the practice range's plywood figures (drawn from it) and when
   `HitConfig.fit` is null.
3. **Cheaper where it counts:** a character's volume is built only once a BB's path comes near it
   (`Hitbox.may_touch`, `HitConfig.volume_reach` and `volume_top`), at most once a tick (BBStep), and a bot's line of
   fire check skips mates nowhere near the line.
4. `VaultState.clip_share` is the Vault clip's share for the drawn figure and the volume both.

## Numbers

HitAreaProbe (M85's measure: 1 cm grid, 8 sides, 19 poses), percentage points of the drawn body missed and of the
volume that is thin air. M85's bar is 4 missed, 3 thin air.

| Figure | Mean missed | Mean thin air | Worst missed | Worst thin air |
|---|---|---|---|---|
| Human, HighCut | 1.4 | 1.2 | 2.1 (aim down) | 2.3 (crouch-walking back) |
| Human, Cap | 1.5 | 1.3 | 2.2 (aim down) | 2.4 (crouch-walking back) |
| Human, Boonie | 1.9 | 1.3 | 3.4 (aim down) | 2.3 (crouch-walking back) |
| Human, FullCut | 1.3 | 1.3 | 2.0 (aim down) | 2.3 (crouch-walking back) |
| Robot (Dev) | 0.7 | 7.4 | 0.9 | 8.0 |
| FI7's built-in volume | – | – | 36 (crouch-walk) | 37 |

`test_hit_registration.gd` fires BBs at 160 m/s through BBStep from three sides at eight poses: at least 93 % of
those at the drawn body strike it and 95 % of those just beside it pass (the built-in volume struck 64 to 75 % of a
crouched, crouch-walking or running figure).

A built volume costs about 67 µs (the built-in 40 µs), but it is built only for a character a BB's path comes near,
once a tick at most.

## Defaults taken (for the owner to check)

- **Baked, not read at load:** the owner's ruling (DECISIONS, 2026-10-16) has the fit read from the clips as the
  figures load; the bake is committed instead, so the simulation has no scene in it and plays the same on every
  machine, and `test_hit_fit.gd` fails until a changed figure is re-baked.
- **Arms and replicas still don't count** (owner, 2026-10-01). A BB clipping only an elbow sticking out flies on.
- **Robots** (Dev) use the human's fit: KNOWN_ISSUES.
- **Headgear:** one head sphere for the four heads (the tuner measured the HighCut; the others are within the bar).

## Tests that moved

- `test_grenades.gd` › BBs fly through smoke: its shot had spread and fired before the aim settled, and only grazed
  the built-in volume's oversized head; it now fires with no spread a tick after aiming, at the chest.
- `test_lean.gd`: the fitted head sits a little off the centre line, so the leaned head is checked as rolled about the
  hip pivot (and Lean.offset as the same roll on the line).
- `test_range_targets.gd`: the plywood figures match the built-in volume (`fit` null), not a match character's.
- `test_bot_bombs.gd` › whole matches on Depot: three seeds instead of two. With the new hits seeds 1 and 2 dazzled 2
  enemies and 2 teammates, too few to tell; three give 12 to 5.
- `test_hitbox.gd`, `test_bb_step.gd`: the built-in volume (`fit` null), which they were written for.

## Checks

Unit tests in four parts locally (1106, 734, 1534 and 1353 tests) with every failure above fixed and its file re-run;
gdlint clean; the changelog note checked. CI is the judge for the whole run.
