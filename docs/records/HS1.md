# HS1 · Replicas worn on the figure: the pistol in the holster, the rifle on the back

**Review:** 3 attempts (and a check of the port onto main) · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (sling thread) | – | Retry 5/8 | The Cyber Pistol through the holster's back wall; the pistol rigid on the hips while the holster's foot follows the thigh; the rifle's gap to the pack; sling names left; no decision or known-issue entries; no QA or performance reports |
| 2026-11-05 | 2 | Claude (sling thread) | 4761/4764 (3 stale tests, fixed) | Retry 6/8 | The sniper's ends stand past the pack (put to the owner); the fit read only the pack's corners; no test pinned the fit to the pack; QA and performance not rerun |
| 2026-11-05 | 3 | Claude (sling thread) | targeted figure tests green; full run on the final branch | Accept 8/8 | – |

## Background

The thread began as SL1, a modelled two-point rifle sling. The owner dropped it on 2026-11-05 16:18: "i don't like the
rifle sling. remove it completely. the player should just hold replicas in their hands. pistols are holstered and
rifles (and any other weapon) can just be clipped onto the plate carrier/belt or whatever when Holstered". None of the
sling ever reached `main`, so nothing was removed from the repo.

## What changed

- **Out of the hand, a replica stays on the figure** (FigurePose, FigureHands). The first rifle rides on the back
  whenever it isn't in the hand. The first pistol sits in the belt holster whenever it isn't in the hand. Before, the
  rifle showed on the back only while holstered and vanished with the pistol drawn, and a pistol out of the hand was
  never drawn.
- **The holster's seat** is an empty, `PistolHolster`, that `tools/blender/figure-gear/gear.py` writes into
  `human.glb` beside BL12's holster. It uses the replica's axes: +Z up out of the mouth toward the grip, +Y the slide's
  top toward the figure's front. It sits at the mouth, on the front inner wall, mid-pocket. FigureModels
  reads it once in the frames of `holster_bone` (Hips) and `holster_follow_bone` (Thigh_R). The pistol is carried by
  the hips with `holster_follow` (0.1) of the thigh's swing. BL12 skins the holster to the hips, with up to 0.35 of the
  thigh at its foot. A rigid pistol can't bend with that, and 0.1 kept the Cyber Pistol inside it when crouched (0.2
  and 0.3 showed it through the side). The rest of `human.glb` is byte-identical when rebuilt.
- **The seat's depth, checked against the pocket:** each pistol's figure mesh was tested in the holster's profile (the
  inner wall 4 mm inside `gear.py`'s outline, 40 mm across) at depths from 0.06 to 0.18 m. Both clear the walls from
  0.10 to 0.13 m. At 0.17 m (attempt 1), the Cyber Pistol's trigger guard went through the narrowing back wall, and the
  GBB Pistol's grip went through the top corner. `holster_depth` is 0.11 m, so the muzzle stays clear of the foot's
  bend when crouched. Renders standing, crouched and sprinting are in this thread.
- **After BL12 merged** (2026-11-06) the holster sits further forward on the hip (the owner: "more to the side/front
  of the hip", BL12's HOLSTER_AT 292°) on a higher belt, its shell canted on a level mount. The seat is placed on the
  shell's cant, so it follows the holster wherever BL12 puts it; the shell's shape is unchanged, so the depth fit holds.
- **The rifle on the back rests on the pack** (the owner, 18:01: "the rifles are floating. They should be holstered
  directly onto the backpack"). FigureConfig's numbers are renamed from `sling_*` to `back_*` and now place the rifle's
  middle (`back_middle`, 1.28 m up on the spine), nearly upright (`back_tilt` 0.3) and leaning with the pack's sloped
  back (`back_lean` 0.3). Then FigureModels moves each replica straight out or in until it rests `back_rest_gap` (3 mm)
  off the kit behind it: the pack's and carrier's triangles rigged to the Chest bone, against every triangle of the
  replica's figure mesh, both looked at in 1.5 cm squares. Only rifles are fitted (a pistol never goes on the back).
  A test poses the figure and checks each rifle's sampled surface against the posed pack: none in it, the nearest
  within 1.3 cm. This is worked out once per mesh and kind. Measured in game on the posed, skinned pack, the AEG
  lies 0.6 to 3 cm off the pack along its length (below the pack's rounded top) and comes to 6 mm of it. Any new
  replica model gets the same fit, so the bots' new replicas will rest on the pack too.
- **The robot** has no holster (no empty), so its pistol out of the hand isn't drawn. Its rifle rides on its back as
  before.
- **Names:** there's no sling any more, so the code calls the slots `on_back` and `in_holster` (FigurePose,
  FigureHands; `FigureModels.on_back`, `on_back_frame`). Before, they were `slung`, and the old `holstered` was easily
  misread beside `Armament.holstered`. `gear.py` returns the seat from `belt_gear` rather than setting a global.
- **Pictures:** `tools/render_stowed.gd` (dev only) renders a figure with a replica stowed, from named views (standing,
  crouched or sprinting).

## Decisions (defaults the owner can change)

- **Where the rifle goes:** on the back, resting on the pack, nearly upright, the butt by the right shoulder. This keeps
  it clear of the arms and legs and reads clearly from behind. The owner said "clipped onto the plate carrier/belt or
  whatever". A front single-point hang would cross the thighs when walking.
- **Which replicas stow:** the first rifle and the first pistol in the loadout (a loadout holds one of each).
- **Long rifles stick out past the pack (owner, 19:14, on a choice card):** the sniper rests on the pack with its ends
  past it; no straps are modelled.
- **No clip model:** the rifle rests on the pack with no modelled clip or strap, since the owner dropped the sling.

## Known issues left (in KNOWN_ISSUES)

- A rifle is rigid and longer than the pack, so its ends stand past the pack: the AEG's muzzle about 10 cm below it,
  the sniper's ends above the shoulder and below the pack. Nothing modelled holds it there; a strap or clip would be a
  new model, and the owner had just dropped the sling.
- The robot has no holster, so its pistol isn't drawn out of the hand. Robots get no further work (the owner).
- Crouched, a speck of the Cyber Pistol can show at the holster's foot (the holster bends with the thigh).
- The rifles on the figures are still the old blue placeholders; the "Model replicas held by bots" thread replaces them.
