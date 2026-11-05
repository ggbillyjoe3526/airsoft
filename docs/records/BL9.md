# BL9 · The smoke and flash bombs' models

**Review:** pending (critic Retry 6/8 on attempt 3; qa Pass; performance Pass)

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | model tests pass (3 files) | art Retry | the fuze body showed through the head's chamfer; the head read charcoal, not black; the lever arm thin and upright; the head's outline and the crown's notches off the photo's; the flash's ring small and edge-on, its cap pale, its ends knife-sharp |
| 2026-11-05 | 2 | Claude (build thread) | `tools/check.sh` pass (4,748 tests) | art Accept; QA Fail | a smoke at rest lay lever down, sunk 8.4 mm into the ground |
| 2026-11-05 | 3 | Claude (build thread) | `tools/check.sh` pass (4,757 tests) | Retry 6/8 (QA Pass, performance Pass) | an unused paints list left in GrenadeView; a stale triangle count in ASSETS; the review line written ahead of the verdict; the reports not on the reviewed head |
| 2026-11-05 | 4 | Claude (build thread) | | | – |

## What changed

The smoke and flash bombs were plain cylinders; they are now modelled from the owner's photos (`ref_images.zip` ›
`grenades`), unbranded, by `tools/blender/grenades/grenades.py`:

- **Smoke** (`assets/models/grenades/smoke.glb`, 5,292 triangles): the M18-style canister, 55 mm across and 140 mm to
  the head's top, measured from the photo at 0.2015 mm a pixel. A grey label sleeve with a light band at each end and
  the kind's stripe under the top one, a castellated black cap with twelve V notches, a black fuze head under a
  channel-section lever (its top plate chamfered at both ends, its lower edge sloping), the arm down the right side to
  just past halfway, flaring 2 mm, with three notches and a slanted tip, a pivot rivet, the pull pin's leg with its
  bent tail, and a dark steel ring.
- **Flash** (`assets/models/grenades/flash.glb`, 3,460 triangles): the pull-ring tube, 40 by 130 mm, olive card with
  rolled ends, the kind's band round the top wrapping over the rim, a sealed cap with a hole in the middle sitting
  just inside it, and a two-turn split key ring (its wire twelve-sided, so it reads round in the hand) hanging from a wire hook over the rim.
- **In the game** (`GrenadeView`): each slot and the bomb in hand draw the kind's mesh, swapped only when the kind
  changes; the `Kind` material is painted from `BODY_COLOURS`, so the models match the HUD's bomb icons. A bomb at
  rest lies on its side, the smoke's lever up, lifted by the model's own lowest reach that way (QA found the smoke
  sunk 8.4 mm with its lever down). A model that won't load falls back to the old canister. Every material the models
  draw is prewarmed.

## Decisions

- Unbranded: no logos, text or product marks on either label.
- The smoke's stripe and the flash's band take the game's kind colours (green, violet) where the photos have the
  product's colour (black or red; yellow or green), so they match the HUD.
- The flash's cap is dark plum, not the photo's red: red is within 20° of High contrast Beta's hue.
- The smoke's pull ring hangs in front of the head, turned 25°, where the photo's passes behind the lever: nothing
  clips, and the build fails if the ring ever enters the head.
- The flash photos in `flash_grenade/` show a smoke tube of the same maker; the flash takes their shape, the smoke
  the canister, so the two bombs are told apart by shape as well as colour.
- Budget: 5,500 triangles and 200 KB a grenade (`docs/CC0_ASSETS.md` › Grenade models), a prop's budget with room
  for the hand view; at most twelve bombs fly at once.

## Known issues

- Each bomb draws one surface per material (smoke 7, flash 6) where the old canister drew one: at most about 90
  extra opaque draws while twelve bombs are live, shadows off (performance, advisory). Not measured on a GPU; a Low
  preset check in play would confirm.
