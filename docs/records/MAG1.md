# MAG1 · The alternative magazines as their own models

**Review:** 3 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | targeted tests pass (88 + 4) | Retry 6/8 (QA Pass, performance Pass) | extended base pad big against generic photos; streaks and slivers round the holes; catch window raised, not cut; base plates and nozzle not the standard's; budget spent on rings; two renders cropped; .uid uncommitted, unused parameter, long line |
| 2026-11-05 | 2 | Claude (build thread) | targeted tests pass (43) | Retry 7/8 | low-cap at 84 % of its budget and the test's floor lowered to let it pass |
| 2026-11-05 | 3 | Claude (build thread) | targeted tests pass (5) | Accept 8/8 (QA Pass, performance Pass) | – |

## What changed

The owner (2026-11-05 14:06): "for the other magazines (i think hicap, extended) use the standard magazines for a
replica but just make them longer/bigger. they should be separate models." The pool has three: the AEG Rifle's Hi-Cap
and Low-Cap (`aeg-mag`) and the GBB Pistol's Extended (`pistol-mag`); the Cyber Pistol and the Sniper Rifle take none.
All three were old placeholders (the hi-cap and low-cap from the first AEG, stretched by `fit_parts.py`'s MAG_LENGTH).

One build script, `tools/blender/parts/magazines.py`, rebuilds them in `assets/models/replicaParts/aeg.glb` and
`pistol.glb` by running each replica's own magazine function (`aeg.magazine`, `gbb.magazine`, now taking a name, a
length and a `fine` level) at another length, so each is its replica's standard magazine, longer or shorter, in its
outline, with detail cut into it:

- **Hi-Cap:** 13.0 cm below the well against the standard's 9.9 (1.32), its curve and ribs carried on down, with a
  knurled winding wheel in a collar under the base plate, a thumb bar and screw across it (the reference list's "the
  hi-cap's wheel"). 9,784 triangles.
- **Low-Cap:** 6.9 cm below the well (0.70). 9,962 triangles.
- **Both AEG parts:** the catch window cut 1.2 mm into the left side near the top, with a dark floor (the photos'
  slot), six grip grooves cut across the base plate's foot (those clear of the wheel on the hi-cap), ribs with rounded
  crowns whose ends slope down into the body, and the flare at the well's foot eased over its 4 mm.
- **Extended:** 4 cm longer along the grip's rake (the old part 2.2), two staggered columns of witness holes bored
  1.2 mm into its back (the owner's pistol magazine photos), the catch notch cut into its left side, an exhaust valve
  and feed lips on top, its base pad in the frame's colour. 9,470 triangles.
- Each keeps the part contract: origin on the MagWell, a `_Figure` copy (44, 44, 28 triangles), the replica's paint
  materials. Each is cleaned as exported (no zero-area triangles) and the flat faces round a cut get their own
  normals, so nothing streaks. `fit_parts.py` no longer stretches magazines; `gbb.py` no longer builds the extended.
- `test_magazine_models.gd`: lengths against the standard magazines, widths, MagWell, budget, figures, materials and
  the parts files' 2 MB.

## Decisions

- **The Low-Cap is built too** (the owner named "hicap, extended" with "i think"): it is the third non-standard
  magazine, so it is rebuilt from the standard one the same way, shorter, as its old model was.
- **Lengths:** hi-cap 1.32 and low-cap 0.70 of the standard below the well, the extended 4 cm longer: long enough to
  read at a glance in first person and on the bots' replicas, short of the hands and the ground.
- **The extended keeps the standard's base pad** (critic attempt 1 measured it big against generic magazine photos):
  the pad is traced from the owner's own pistol photo in BL2 and shared with the standard magazine, which he passed
  ("almost perfect"); the owner's rule is "the standard magazines … just longer", so it stays, in the frame's colour.
- **Outlines stay the standard's** (critic attempt 1): the first attempt's flared rim, pull tab and BB nozzle went;
  the detail is cut in, not added on.
- **Detail to the part budget** (owner, 2026-11-05 14:13: aim close to the budget): a part has 10,000 triangles
  (docs/CC0_ASSETS.md › Size limits), the replica's own magazine shares the rifle's 40,000. The hi-cap uses 98 %, the
  low-cap 99.6 %, the extended 95 %: on the curve's rings and rounder corners where they show, the ribs' crowns and
  ends, the shoulder, and the wheel, holes and cuts; not on rings down straight faces (the critic's point in
  attempt 1). The test holds each part between 90 and 100 %.
- **The hi-cap's wheel** has 24 knurls round 36 segments, bevelled 0.15 mm: about 2,200 triangles.
- **No photos of hi-cap, low-cap or extended magazines** were in `ref_images.zip`: the shapes follow the standard
  magazines and their photos (`replicas/aeg_rifle/aeg_magazine`, `replicas/gbb_pistol/gbb_pistol_magazine`).

## Known issues left

- On a bot's rifle the low-cap's figure block is drawn over the replica's own figure, whose magazine is longer, so its
  foot may show under the low-cap at a distance (as with the old part; QA).
- After BL8 (#205) lands, aeg.glb is about 1.8 MB of its 2 MB; the new test guards it.
