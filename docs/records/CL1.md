# CL1 · Climbing out of the track onto a platform, stairs runs, Kingsmere's trackside steps removed

**Review:** critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | ✓ | Accept 7/8 | – (check 8: KNOWN_ISSUES still gave MT1's balance; the wiki's stairs line read as your own view; both fixed in the records commit) |

## Goal

The owner (2026-11-10 13:43): "in Kingsmere the player needs to be able to climb from the tracks up to the platform.
They should be able to climb. If required add a new animation for the player and bots to climb up the platform. Also,
we need animations for running up and down stairs." And (13:46): remove Kingsmere's trackside stairs and any stairs
there only because there was no other way between levels.

## Approach

- **The climb is the vault's plan with no far side.** `Vault.plan` climbs a top 0.6 to 0.95 m over your floor whose
  flat top is open for `VaultConfig.climb_depth` (1.5 m: platforms and docks, never crates or props); the body rises
  (`climb_rise_time`), steps on at `climb_min_speed`..`climb_max_speed` and ends standing `landing_room` past the edge,
  no hop and no push down (`VaultState.climb`). The HUD reads "Space to climb" (HUD_CLIMB).
- **Bots:** `NavVaults` adds a one-way climb link up and its reverse drop link down, merged into the grid's CSR arrays
  in linear time. Only Kingsmere has climbable ledges (453 climbs, 453 drops); Depot, Woodland and the Range none
  (`test_bot_climbs`).
- **Clips, without Blender:** `gait/climb.py` (Climb, 0.6 s: a hand planted on the edge, the trailing knee turned out
  past the face, keyed hips and feet, IK legs, the Vault clip's upper body) and `gait/stairs.py` (Stairs_Up and
  Stairs_Down: Run_F's gait on a 1:2 slope at Run_F's pace and cycle), spliced into human.glb and robot.glb (35 clips).
- **Drawn:** FigureGraph picks the vault or climb clip under the vault's TimeSeek (a Transition) and blends the stairs
  clips over the gait (a Blend3 whose sides are gated Transitions, so the gait's output connects once). The stairs
  share is `Character.stairs`, eased by `Hitbox.step_stairs` from the rise over the ground covered, shown only as far
  as the body steps ahead (`Hitbox.stairs_blend`). HitFit gained CLIMB and STAIRS tables (re-baked) so the hit volume
  follows the drawn legs.
- **First person:** the view's dip and tip peak early for a climb (`ViewConfig.climb_dip`, `climb_tip`, `climb_peak`)
  and ReplicaView carries the replica low until the top.
- **Kingsmere:** `tools/kingsmere/layout.py`'s `track()` lost its steps; the map rebuilt (four step sets gone: both
  ends of the south track, the north track's west end and its stretch east of the train).
- **Pictures:** `tools/climb_pictures.gd` films the climb, the stairs before and after and the first-person climb;
  `/mnt/project-files/concepts/metro/cl1/`.

## Decisions

- **Climbing is Jump at a platform-like ledge** (owner ruling): `docs/DECISIONS.md` › Gameplay and feel, replacing MT1's
  "nobody climbs out of a track pit".
- **Kept: the spiral stair, the ordinary stair, the escalators, the north platform's end ramp into the tunnel, the
  cab steps.** A real station has each; the end ramp is a staff walkway into the tunnel, not a way out of a pit.
- **The stairs clips show only stepping ahead** (strafing or backing on stairs keeps the gait's clips): the clips are
  run cycles; a sideways one would need its own.
- **First person has no climb body:** the view's heave and the replica carried low say it, as the vault's do.
- **The stairs share is cleared on a respawn and on a rescue from out of the world** (QA).

## Checks and balance

- `tools/check.sh`: gdlint, changelog notes, wiki, unit tests (5702, all seven parts; test_assets' clip count fixed
  after the run and re-run), smoke and licence notices pass.
- Balance (8 seeds, Normal, `pipeline/runs/CL1/attempt-1/balance-report.md` in the shared files): Attack / Defend
  attackers 50.9 % ±6.6 (MT1: 67.7 %), Elimination's east end 55.0 % ±6.4 (MT1: 56.7 %), Beta 61.7 % ±6.3 of
  Elimination's rounds (outside its band, within noise); no round ran out the clock.

## Known issues left

- Kingsmere's balance still needs a 32-seed run before tuning (KNOWN_ISSUES, Maps).
- The stairs clips plant feet on the slope's line, not on each tread, so a foot can hover a little over a step or
  touch a riser; fine at greybox.
