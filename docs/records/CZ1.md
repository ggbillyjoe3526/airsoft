# CZ1 · The Cyber Pistol at the GBB Pistol's size

**Review:** 2 attempts · critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (CZ1 thread) | running | Retry 6/8 | the Weapon Torch's back end sank 2 mm into the guard loop (`TorchMount` moved back with the warp, the loop's front less); docs' sizes and "the GBB's reach" wrong; no QA report yet |
| 2026-11-05 | 2 | Claude (CZ1 thread) | ✓ | Accept 7/8 | – (check 8: two code comments, fixed) |

## What changed

- **The owner (2026-11-05 18:37):** the first-person hands' Cyber Pistol hold "is still very bad. Maybe it's because the
  cyber pistol is larger than the gbb? Maybe the cyber pistol needs redesigned to be sized similar to the gbb?" The
  arms thread measured why: every GBB-like thumb pose passed 2 to 7 mm into the Cyber's rear block (16.5 to 18.5 mm a
  side against the GBB slide's 12.8), the frame was 15.8 mm a side (GBB 12.4) and the grip 2 cm longer.
- **`tools/blender/replicas/cyber.py`** still draws BL6's design at its size (the look the owner approved), then
  `warp` fits every built mesh to the GBB's envelope: lengths ×0.89, heights ×0.72 above the bore's foot and ×0.84
  below, widths ×0.72 on the shroud, slide, rear block and cap, and on the frame 12.4 mm a side (the GBB's frame)
  flaring to 15 mm on the grip (the GBB's grip) between z -20 and -40 mm (before the warp). The custom (weighted)
  normals go through the warp's Jacobian, so the shading stays as `hs.finish` made it. Bones, empties and the clips'
  keys go through `fit` (centre-line points), the slide's and selector's travel through the length scale.
- **Kept their own widths:** the rail (20 mm, so the Weapon Torch's flush clamp still fits it), the trigger blade, and
  the sights (below).
- **The iron sights show (owner, 2026-11-05 19:12: "you can't see the cyber pistols iron sights").** Aimed, the eye
  sits on the sight line (the `RearSight` empty's height); BL6's rear notch floor sat on that line, so the rear sight
  hid the whole front post (the GBB's GS1 bug). Now the notch floor is 2.1 mm under the line and the rear sight's top
  0.5 mm over it, the post 3.2 mm and the notch 4 mm wide (the GBB's), so the post and its glowing dot stand in the
  notch with light either side. The sight line rose 2 mm (before the warp) so 2.5 mm of rear sight stays under the
  notch's floor: with the floor at its foot, the back face's triangles bridged the notch. `tests/unit/test_cyber_sights.gd`
  ray-tests the sight picture as `test_pistol_sights.gd` does the GBB's.
- **Round parts on the sides** (screws, the cap's and cell's glowing rings, the fire-mode lights) are drawn
  pre-squashed in `place`, so they come out round.
- **Size:** 229 × 193 × 38 mm before, 206 × 152 × 32 mm now (the GBB: 204 × 140 × 31). The grip is 55 to 59 mm front to
  back and 30 mm across (the GBB's 58 to 61 and 31); the top is at 26.6 mm (the GBB's 26.1), the bore at 10.8 (10.5),
  the sight line at 30.2 (25.7).
- **Thumb room:** the rear block's skirt (below z -8 mm before the warp) is sunk 0.8 mm, from BL6's 1.2, so it sits
  0.3 mm proud of the frame, as the GBB's slide does; the band above it 0.9 mm.
- **Budget:** 37,824 triangles in the hands (the glTF count) (40k; the owner's ~95 % rule), spent on 4 segments per outline fillet
  (BL6: 3) and a third bevel segment on the muzzle block and frame, two on the cell, three on the base pad. Figure
  version 240.
- **The torch part** (`replicaParts/cyber.glb`) rebuilt by `tools/blender/parts/attachments.py`'s `write("cyber")` at
  the moved `TorchMount`; the other parts files untouched. `write` now stops the build when a part of a file in
  `CLEAR_OF_BODY` touches the replica's Body (a BVH overlap of every face; the Cyber's torch: 0 pairs, 3.6 mm clear at
  its nearest; the attempt-1 model gives 222 pairs and stops).

## Decisions

- **The trigger moves 13 mm nearer the grip** (11.6 mm at the new size; bone y -7.6 mm, the GBB's -5.4), the guard
  opening's back wall 4.5 mm with it (4 mm behind the blade, 4 mm ahead of the grip's front). BL6's trigger sat 19 mm
  further from the back strap than the GBB's, and the owner's trigger ruling (2026-11-05: "the player would need to
  stretch their finger") went the same way. Default taken, told to the owner with the pictures. The reach from the back
  strap (at z -25 mm) is 73.6 mm to the GBB's 68.3: the back strap stays where BL6 drew it, since bringing it forward
  means moving the cell and its windows inside the grip too; the arms' hold is fitted to the grip, not to that gap.
- **The guard's front moves 7.5 mm back** (before the warp: the opening's front wall to 26.2, the loop's lower front to
  34.5), so the opening, which the trigger left 38 mm long ahead of it, is shorter, and the Weapon Torch's back end
  clears the loop.
- **A shallower base pad** (to z -144 mm before the warp, BL6's -151), so the grip ends 7 mm under the GBB's magazine,
  not 13.
- **A warp, not a redrawn outline:** BL6's design is a few hundred hand-placed millimetre marks the owner approved; one
  documented fit keeps every one of them in proportion and makes the next size change a constant.
- Pictures for the owner: `/mnt/project-files/art/blender/cyber/cz1/`.

## Known issues left

- The first-person arms' Cyber hold (PR #204) and the bots' Cyber copy (PR #220) were fitted to BL6's size; those
  threads refit them after this merges.
