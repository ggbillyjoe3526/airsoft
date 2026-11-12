# MQ1B · The Cyber Pistol's grip in the GBB Pistol's shape

**Review:** 3 attempts · critic PENDING · qa PENDING · performance PENDING

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | pass | Retry 7/8 | A pin stood out of the tang; the skin showed facets and bands; the web and frame left ledges over the grip's top; the base pad was a square block wider than the grip |
| 2026-11-12 | 2 | Fable 5.2 (model quality thread) | pass | Retry 6/8 | The square corners of the GBB's frame ran down the back of the white shell as two creases from the tang; the cell's ribs notched the window's edge; docs/ASSETS.md and docs/KNOWN_ISSUES.md not updated |
| 2026-11-12 | 3 | Fable 5.2 (model quality thread) | PENDING | PENDING | – |

## What changed

Owner, 2026-11-12, on MQ1's pictures: "the cyber pistol can you redesign the handle/grip to be a similar shape to the
GBB pistol?" and "The cyber grip doesn't look ergonomic. It has flat and sharp edges." On the first version's
pictures: "Can you make the handle less curved on the back side? Also; the black grip area should be slightly smaller
and angled in the same direction as the handle." On the second version's: "Perfect".

The Cyber Pistol's grip was a flat slab with bevelled edges, a straight back and a toothed front. It is now the GBB
Pistol's rounded grip with a straight back: `tools/blender/replicas/cyber.py` lofts the GBB's rounded sections
(`gbb.grip_ring`, the photo tables `gbb.py` already holds) where the GBB's sit, taken back through the Cyber's warp
(`unfit`) so they land at the GBB's size. The two replicas have shared an origin and a size since CZ1, so the front
strap, the finger grooves and the width are the GBB's to within 1.5 mm down the grip.

- **The back strap** (`back_strap`, `BACK_NOTCH`, `BACK_HEEL`): a straight line from the hollow under the tang (filled
  2.5 mm) to the heel (drawn in 2.5 mm), the tang's curve blended in above it. The GBB's swells 1.8 mm off that line;
  the Cyber's is on it, within 4.2 mm of the GBB's everywhere (the grip is 0.94 to 1.08 times as deep), so a hand
  still holds both alike. Behind its widest, every section is as round as the GBB's palm (`BACK_ROUND`), up to the
  tang: the GBB's frame is a square block there, and its corners showed on the white shell as two creases.
- **The window** (`grip_window`, `WINDOW_Z`, `WINDOW_HALF`): a parallelogram on the handle's middle line, so it leans
  as the handle does; 27 mm wide and 66 tall as drawn, smaller than the first version's. The power cell behind it
  (`cell_outline`) is raked on the same line and stays inside the rounded walls all the way down, its ribs ending
  inside the window so the window's walls stand on a clean face; the reload clip and the `magazine` bone are as
  they were.
- **The base pad** (`pad`, `PAD_TIERS`): the foot's own rounded outline carried down the handle's rake, a chamfered
  metal plate, a groove and a dark foot, 12 mm tall at the GBB's size and inside the grip's width and length.
- **The frame's top** blends into the grip: the web behind the trigger narrows to the grip's rounded front
  (`GUARD_WEB`) and the spine sits inside the grip's top (`FRAME_SPINE`), so no ledge stands over either strap.
- **Still the Cyber Pistol:** the white coated shell, the dark ribbed power cell with its pink ring, a base pad. The
  slide, shroud, rear block, guard loop, trigger, rail, sights, bones, clips and empties are untouched; the torch
  still fits.
- **Gone:** the slab's front serrations, its ring groove, the back grooves, the two grip screws and the pin through
  the tang.
- **Triangles:** 38,706 in the hands (budget 40,000; was 37,824), the figures' copy 3,000 (decimated from the new
  shape, so a bot's Cyber Pistol has the grip too).
- **Tests** (`tests/unit/test_cyber_grip.gd`): the Cyber's front strap and half width match the GBB's at four heights
  down the grip, its back strap is a straight line where the GBB's swells, and its sides draw in toward both straps
  as the GBB's do. QA's `tests/unit/test_mq1b_qa.gd` holds the model's contract (size, empties, clips, the cell inside
  the grip, budgets).
- **The model studio** (`tools/model_studio.gd`): the camera's depth now hugs each shot. The sun's shadow map is
  spread over that depth, and with the whole stage in it a close-up's shadow edges were drawn in millimetre-wide
  steps that read as faults in the model. It also asks for the largest shadow map.
- **Docs:** the rulings in `docs/DECISIONS.md` › Replicas; the wiki's Cyber Pistol line; the model's row in
  `docs/ASSETS.md`; the hands' hold in `docs/KNOWN_ISSUES.md`. The play check is on the Dev 3 checklist, which is
  kept in the shared project files (`playtest/0.1-dev3-checklist.md`), not in this repository.

## Decisions

- **The GBB's sections themselves, not a look-alike** (default): the owner asked for "a similar shape", and the same
  sections mean the first-person hands can hold both pistols alike (the FP arms thread owns the hold tables and refits
  the Cyber's after this merges).
- **A straight back, not a flatter curve** (default): "less curved" is read as straight between the tang and the
  heel, which also suits the Cyber's angular lines; `BACK_NOTCH` and `BACK_HEEL` set how far it leaves the GBB's.
- **One window a side, the cell's outline drawn in** (default): the old grip's cell filled the whole slab side; on a
  rounded grip a window that large left no wall for the palm. The window keeps the design's dark panel and ring.
- **No grooves across the back** (default): the first version's six grooves banded the skin and fought the straight
  back; the finger grooves on the front strap stay.
- **No wear, no stipple** (owner, RW1: the Cyber stays clean): the grip is the shell's coated white.
- **`arms.glb` is not rebuilt here** (shared binary, owned by the FP arms thread): the hands' Cyber hold was posed on
  the slab. In the review pictures the hand sits on the new grip without sinking in; the refit is that thread's.

## Known issues left

- The first-person Cyber hold (`tools/blender/arms/arms.py` `cyber`, `CYBER_RIGHT`) still carries the slab's numbers
  until the FP arms thread refits it (`docs/KNOWN_ISSUES.md`); the play check is on the Dev 3 checklist.
