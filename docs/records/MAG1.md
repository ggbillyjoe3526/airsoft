# MAG1 · The alternative magazines as their own models

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | targeted tests | pending | – |

## What changed

The owner (2026-11-05 14:06): "for the other magazines (i think hicap, extended) use the standard magazines for a
replica but just make them longer/bigger. they should be separate models." The pool has three: the AEG Rifle's Hi-Cap
and Low-Cap (`aeg-mag`) and the GBB Pistol's Extended (`pistol-mag`); the Cyber Pistol and the Sniper Rifle take none.
All three were old placeholders (the hi-cap and low-cap from the first AEG, stretched by `fit_parts.py`'s MAG_LENGTH).

One build script, `tools/blender/parts/magazines.py`, rebuilds them in `assets/models/replicaParts/aeg.glb` and
`pistol.glb` by running each replica's own magazine function (`aeg.magazine`, `gbb.magazine`, now taking a name, a
length and a `fine` level) at another length, so each is its replica's standard magazine, longer or shorter:

- **Hi-Cap:** 13.0 cm below the well against the standard's 9.9 (1.32), its curve and ribs carried on down, with a
  knurled winding wheel in a collar under the base plate, a thumb bar and screw across it (the reference list's "the
  hi-cap's wheel"). 9,760 triangles.
- **Low-Cap:** 6.9 cm below the well (0.70). 9,836 triangles.
- **Extended:** 4 cm longer along the grip's rake (the old part 2.2), witness holes bored down its back (the owner's
  pistol magazine photos), an exhaust valve and feed lips on top, its base pad in the frame's colour. 9,569 triangles.
- AEG parts also get a flared rim, pull tab and grip ridges on the base plate, the catch window and a BB feed nozzle.
- Each keeps the part contract: origin on the MagWell, a `_Figure` copy (44, 44, 28 triangles), the replica's paint
  materials. `fit_parts.py` no longer stretches magazines; `gbb.py` no longer builds the extended one.

## Decisions

- **The Low-Cap is built too** (the owner named "hicap, extended" with "i think"): it is the third non-standard
  magazine, so it is rebuilt from the standard one the same way, shorter, as its old model was.
- **Lengths:** hi-cap 1.32 and low-cap 0.70 of the standard below the well, the extended 4 cm longer: long enough to
  read at a glance in first person and on the bots' replicas, short of the hands and the ground.
- **Detail to the part budget** (owner, 2026-11-05 14:13: aim close to the budget): each is 9,569 to 9,836 of a part's
  10,000 triangles (docs/CC0_ASSETS.md › Size limits), from finer rings, corners and bevels (`fine`) and the details
  above. The replica's own magazine is unchanged (it shares the replica's 40,000).
- **The wheel's knurls are bevelled at 0.2 mm, one segment**, so the wheel stays about 1,500 triangles.
- **No photos of hi-cap, low-cap or extended magazines** were in `ref_images.zip`: the shapes follow the standard
  magazines and their photos (`replicas/aeg_rifle/aeg_magazine`, `replicas/gbb_pistol/gbb_pistol_magazine`).

## Known issues left

- None yet.
