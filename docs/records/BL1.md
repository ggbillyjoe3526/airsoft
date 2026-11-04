# BL1 · Blender batch 1: the AEG Rifle

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-04 | 1 | Claude (build thread) | 2 unit tests failed (barrel end moved) | Retry 5/8 | the right hand did not grip; docs claimed more than the build; owner's 15:10 review |
| 2026-11-04 | 2 | Claude (build thread) | pass | Accept 7/8 (QA Pass, performance Pass; image rounds 4 to 10, all 25 ratios within 10 % at round 10) | – |

## What changed

- **The AEG Rifle's model** (`assets/models/replicas/aeg.glb`), rebuilt from the owner's reference photos
  (`ref_images.zip`, 2026-11-04) by `tools/blender/replicas/aeg.py` and matched to his main photo (a left-side view of
  a short quad-rail carbine) by a measured overlay, round after round, until the image critic's ratios fell within
  10 %: a quad-rail handguard (a ribbed cover on the left, bare rails top, bottom and right, a raised bridge of rail
  over the receiver's front, a finely ribbed delta ring, a thin front cap), an open A-frame front sight base (a collar at each end, daylight
  between them over the bare barrel), a
  flip-up rear sight leaning back on a low base with a windage drum and a hooked rear ear, a flat-top upper (ejection port, brass
  deflector, forward assist blended into the side), a lower with a raked, flared magazine well and a trigger guard
  that runs down into the grip, a pistol grip raked 30° with a finger swell, a crane-style stock (battery tubes, an open toe plate with a
  slot along it, a slot down it and a pin hole, the adjustment lever, a rounded ribbed pad) on a castle nut, a curved
  magazine with five ribs a side and a square base, and a birdcage flash hider behind two bands. 39,698 triangles in the hands
  (budget 40,000), its figure version 328, 7 materials.
- **The owner's reviews (2026-11-04).** 14:12 and 14:13: shorter; the trigger guard "has a big gap in it"; the hands
  "are terrible". 15:10 to 15:12: "too short now", the magazine "slightly too long", the wrist "at a very strange
  angle", "pay close attention to reference images", "the critic needs to be more harsh" (so the critic's brief,
  `.claude/agents/critic.md`, gained a Models rule: proportions measured on the owner's photos within 10 %, no gap,
  clipping or faceting in a close-up, poses a hand can hold, AAA next to the reference). 16:49: "That doesn't look
  anything like the reference image. Match the reference images as close as possible." 17:09: the rifle as short as
  the photos. So the rifle is his photo's carbine, about 67 cm with the stock in (barrel end 0.339 m, muzzle 0.380),
  the magazine 9.9 cm below the well's foot.
- **Iron sights under an optic** (owner, 17:10: "should fold or disappear when a scope or optic is fitted"). The front
  sight's ears and post are the `FrontSightLeaf` on the `frontSight` bone, the rear housing the `RearSightLeaf` on
  `rearSight`; `SightFold` (`game/play/sight_fold.gd`) now also shrinks the bones in its `HIDDEN` list to nothing at
  their heads, so both disappear with an optic and come back without one (an A-frame can't fold flat, and the rear
  leaf folded would lie under an optic's mount). `test_parts_in_play.gd` checks both.
- **Same contract.** Every empty, bone and the five clips are there. Moved with the photo's shapes: `Muzzle`,
  `BarrelEnd` (0.339), `FrontSight` (0.318), `RearSight` (y -0.0307; the sight line stays at 0.098), `MagWell`
  (a little higher with the deeper lower), and the `frontSight`, `rearSight` and `trigger` bones' heads.
  `tools/blender/parts/fit_parts.py` (new) puts each part in `replicaParts/aeg.glb` back on its mount; it can be
  re-run after any replica changes shape. Three unit tests follow: the silencer on the long barrel, the rear sight's
  place (`test_parts_in_play.gd`) and the sniper's barrel 42.6 cm past the AEG's (`test_sniper_rifle.gd`).
- **Shared helpers** `tools/blender/replicas/hardsurface.py`: prisms, lofts, lathes, fillets, Chaikin smoothing,
  booleans, the finish pass, bones and export, for the rest of the Blender batches.
- **The Sniper Rifle** placeholder re-run (`sniper.py`) from the new AEG, its barrel run on 42.6 cm so it keeps its
  length (barrel end 0.765 m as before); `sniper.py` stops if the AEG's `BarrelEnd` is not where it expects. 39,838
  triangles in the hands.
- **The figures' rifle seat** (`human.json`, `robot.json`, from `bot14.py`'s `RIFLE_SEAT`): the rifle moved in the
  fist so the new grip's middle sits where the old one's did, the barrel's line kept (a known issue until the figures
  batch re-seats both hands).
- **First-person arms: taken out of this batch.** The arms (the MakeHuman base mesh, CC0, under a glove and sleeve)
  were built and their hold solved with no clipping and both wrists within 30°, but in a close-up the right hand lay
  flat on the receiver's side with its little finger off the grip (the solver's fingertip check was satisfied by the
  receiver, not the grip). They are not drawn in game yet, so they move to the arms-in-game step, which solves the
  hold for each replica and is judged in game; the work so far is kept outside the repository, in the
  project's shared files (`/mnt/project-files/art/blender/arms-wip/`).

## Decisions

- The photo's length over "too short now" (15:10): the owner's later "match the reference images" (16:49) and his
  pick on the length card (17:09).
- The photo's vertical foregrip is not part of the rifle: grips are parts in the game, fitted under the handguard.
- The left rail keeps its cover (as in the photo); the right one is bare, so the torch still mounts there.
- The replica materials stay at 7: `Body`, `Furniture`, `Detail`, `Accent` and `Metal` are the paint scheme's slots,
  `Rubber` the pad, `BB` the BBs at the magazine lips; merging them would lose paint slots.
- Plain colours, no textures: `ReplicaPaint` overrides the five scheme materials with flat colours, so detail lives in
  geometry and normals.
- No brand marks or trademarked shapes: the photo's logos are left off; the shapes are a generic carbine's.
- The arms wait for the arms-in-game step rather than ship with a hold that fails a close-up.

## Known issues

- The figures' hold on the new grip (a row in `docs/KNOWN_ISSUES.md`).
- The Sniper Rifle is still the AEG-based placeholder; the bolt-action model from the owner's photos is a later
  batch.
