# BL3 · The AEG Rifle's fixes

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | targeted tests pass (6 files) | Retry 7/8 (QA Pass, performance Pass) | the charging handle sat in the buffer tower and stock; trigger 5.7 mm forward; a shelf where the grip met the receiver |
| 2026-11-05 | 2 | Claude (build thread) | targeted tests pass (9 files) | Retry 7/8 (QA Pass) | trigger 5.4 mm too far back; grip panel short; finger groove filled in; heel |
| 2026-11-05 | 3 | Claude (build thread) | targeted tests pass (9 files) | Retry 7/8 (QA Pass) | a pinch on the back strap; two faces sharing the upper's back plane |
| 2026-11-05 | 4 | Claude (build thread) | targeted tests pass (9 files) | Accept 8/8 (QA Pass, performance Pass) | – |

## What changed

The owner's five fixes on the AEG Rifle (`assets/models/replicas/aeg.glb`, built by `tools/blender/replicas/aeg.py`),
worked from his main photo (`ref_images.zip` › `replicas/aeg_rifle`), not the markup that pointed at them:

- **Trigger** (orange): it faces the right way, its tip curving forward as in the photo, and sits where the photo's
  does, 65 % across the guard's opening (its pivot bone at y -0.0067).
- **Charging handle** (red): a bigger T with a latch on its left wing, behind the rail's end, on a long shaft in a
  channel under the rail (cut into the rail's foot, 2 mm under its top face). The Inspect clip pulls it 5 cm back and
  home again. The owner's 05:52 note ("still clipping, no space to pull it out"): the T rides 5 mm clear over the
  buffer tower, the castle nut and the stock, the T 2.5 mm higher (z 0.0665 to 0.0750) and the stock's top 1.5 mm
  lower (`STOCK_TOP` 0.0615).
- **Top rail** (green): the raised section over the handguard's front is gone; the upper's rail runs level onto the
  handguard's, the teeth in step, and the bottom and right rails and the rail cover reach the delta ring with no gap.
- **One lower** (blue and purple): the magazine well is one prism with the lower, flush with its sides (no step above
  the body), and the pistol grip is a union with the lower in the same `Body` material. The grip's top takes the
  lower's squared section and eases into its rounded one over the middle half of its length, its back strap following
  the photo's: straight, then curving into the receiver. Its front follows the photo's finger groove
  and swell within 1 mm, its heel the photo's within 0.2 mm. Its stippled panels (`GripPanels`, 0.4 mm proud) run from
  under the moulded top to the foot, 21 mm wide and 4 mm behind the finger groove.
- **The rail's back** stands 0.2 mm in from the upper's back and is closed for its last 2 mm either side of the
  charging handle's channel, so no two faces share the upper's back plane (they flickered under the handle).
- 39,816 triangles in the hands (budget 40,000), the figure version 340; 12 meshes, 26 primitives, 7 materials, the
  same bones, empties and clips. `fit_parts.py` moves no part. The Sniper Rifle is built from the AEG's model
  (`sniper.py`), so it takes the same grip, trigger and stock.

## Decisions

- The charging handle's T stands 2.5 mm higher than the photo's, and the stock's top 1.5 mm lower, so the handle has
  room to pull back (owner, 05:52). The photo's T sits right on the stock's top line.
- The handle travels 5 cm in the Inspect clip: far enough to read as pulled, inside the channel, the shaft still
  5 mm into the upper.
- The grip's stippled panels are pads standing proud, not recesses: a boolean recess as long as the photo's panel
  cost 2,210 triangles and broke the 40,000 budget; the pads cost 496.
- The grip is one piece with the lower by a boolean union, not a loft from the receiver: the side silhouette stays
  the photo's and the lower keeps its detail.

## Known issues

- The grip's change from the receiver's squared section to its rounded one shows soft facets in a raking light.
- The castle nut's notches leave faceted rims in close-ups (184 triangles are left in the budget).
- The grip's underside sits 1 to 2 mm higher than the photo's just ahead of the heel; the stippled panels' bottom
  corners are short chamfers.
- The Sniper Rifle, built from this model, has 64 triangles left under 40,000: any growth of the AEG's body must be
  paid for there.
