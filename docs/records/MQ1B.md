# MQ1B · The Cyber Pistol's grip in the GBB Pistol's shape

**Review:** 1 attempt · critic PENDING · qa PENDING · performance PENDING

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Fable 5.2 (model quality thread) | PENDING | PENDING | – |

## What changed

Owner, 2026-11-12, on MQ1's pictures: "the cyber pistol can you redesign the handle/grip to be a similar shape to the
GBB pistol?" and "The cyber grip doesn't look ergonomic. It has flat and sharp edges."

The Cyber Pistol's grip was a flat slab with bevelled edges, a straight back and a toothed front. It is now the GBB
Pistol's own grip: `tools/blender/replicas/cyber.py` lofts the GBB's rounded sections (`gbb.grip_ring`, the photo
tables `gbb.py` already holds) where the GBB's sit, taken back through the Cyber's warp (`unfit`) so they land at the
GBB's size. The two replicas have shared an origin and a size since CZ1, so the curved back strap, the palm swell, the
finger grooves and the width are the GBB's to within 1.5 mm down the grip.

- **Still the Cyber Pistol:** the white coated shell, the dark power cell showing through a window in each side with
  its pink ring, a base pad under the foot, six grooves across the back strap. The slide, shroud, rear block, guard
  loop, trigger, rail, sights, bones, clips and empties are untouched; the torch still fits.
- **The power cell** (`MAG`, `MAG_HW`) is narrower and shorter fore and aft so it stays inside the rounded walls all
  the way down; the reload clip and the `magazine` bone are as they were. The base pad moved forward under the new
  foot.
- **Gone:** the slab's front serrations, its ring groove, the old back grooves and the two grip screws.
- **Triangles:** 39,276 in the hands (budget 40,000; was 37,824), the figures' copy 2,998 (decimated from the new
  shape, so a bot's Cyber Pistol has the grip too).
- **Tests** (`tests/unit/test_cyber_grip.gd`): the Cyber's front strap, back strap and half width match the GBB's at
  four heights down the grip, and its sides draw in toward both straps as the GBB's do. The old slab fails the first.
- **Docs:** the ruling in `docs/DECISIONS.md` › Replicas; the wiki's Cyber Pistol line; a play check on the Dev 3
  checklist.

## Decisions

- **The GBB's sections themselves, not a look-alike** (default): the owner asked for "a similar shape", and the same
  sections mean the first-person hands can hold both pistols alike (the FP arms thread owns the hold tables and refits
  the Cyber's after this merges).
- **One window a side, the cell's outline drawn in** (default): the old grip's cell filled the whole slab side; on a
  rounded grip a window that large left no wall for the palm. The window keeps the design's dark panel and ring.
- **Back strap grooves kept, front serrations dropped** (default): the GBB's finger grooves took the front strap's
  place; the grooves across the back keep some of the old grip's ribbed look where a palm sits.
- **No wear, no stipple** (owner, RW1: the Cyber stays clean): the grip is the shell's coated white.
- **`arms.glb` is not rebuilt here** (shared binary, owned by the FP arms thread): the hands' Cyber hold was posed on
  the slab. In the review pictures the hand sits on the new grip without sinking in; the refit is that thread's.

## Known issues left

- The first-person Cyber hold (`tools/blender/arms/arms.py` `cyber`, `CYBER_RIGHT`) still carries the slab's numbers
  until the FP arms thread refits it; the play check is on the Dev 3 checklist.
