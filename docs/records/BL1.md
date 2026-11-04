# BL1 · Blender batch 1: the AEG Rifle and the first-person arms

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-04 | 1 | Claude (build thread) | pending | pending | – |

## What changed

- **The AEG Rifle's model** (`assets/models/replicas/aeg.glb`), rebuilt from the owner's reference photos
  (`ref_images.zip`, 2026-11-04) by `tools/blender/replicas/aeg.py`: a modern carbine with a flat-top upper (ejection
  port, brass deflector, forward assist), a lower with a flared magazine well and trigger-guard, a raked stippled grip,
  a hollow octagonal handguard with slots and short rails, a six-position stock on a castle-nut buffer tube with
  battery tubes and a ribbed pad, a curved ribbed magazine with three BBs at its lips, and a birdcage flash hider.
  34,850 triangles in the hands (budget 40,000), its figure version 320 (budget 3,000), 7 materials (the old file
  had 8; `Tip` was unused).
- **The owner's review (2026-11-04, 14:12 and 14:13).** "Make the AEG shorter"; the trigger guard "has a big gap in it.
  It's not attached to the body"; the hands "are terrible", must look realistic with no clipping, and the arm "is too
  long. It doesn't look natural". So: the barrel and handguard are 15.4 cm shorter (CQB length) and the stock sits one
  position in (3 cm); the trigger guard is one closed loop whose posts run up into the lower, with lugs at both ends;
  the forward assist is a lofted teardrop (it read as a flat fin). Hard-surface method: exact booleans, a narrow bevel, sharp edges from angle and weighted
  normals, so it reads as machined without textures.
- **Same contract.** Every empty (`Muzzle`, `BarrelEnd`, `RearSight`, `FrontSight`, `MagWell`, `GripMount`,
  `OpticMount`, `TorchMount`), every bone and the five clips (`Fire`, `Reload`, `Selector`, `SightsFold`, `Inspect`)
  are there; the rear ones sit where the old ones did (sight line, grip and magazine unchanged) and `Muzzle`,
  `BarrelEnd`, `FrontSight` and `TorchMount` moved back with the barrel. `tools/blender/parts/fit_parts.py` (new)
  puts each part in `replicaParts/aeg.glb` back on its mount (barrels and silencer to `BarrelEnd`, torch to
  `TorchMount`); it can be re-run after any replica changes shape. The
  selector lever points forward at safe, up at single and back at auto.
- **Shared helpers** `tools/blender/replicas/hardsurface.py`: prisms, lofts, lathes, booleans, the finish pass, bones
  and export, for the rest of the Blender batches.
- **The Sniper Rifle** placeholder re-run (`sniper.py`) from the new AEG, its barrel run on 35.4 cm so it keeps its
  length (barrel end 0.765 m as before); `sniper.py` now stops if the AEG's `BarrelEnd` is not where it expects.
  34,970 triangles in the hands.
- **First-person arms** (`assets/models/arms/arms.glb`, `tools/blender/arms/arms.py`), rebuilt after the owner's
  review: an anatomical arm and hand (the MakeHuman base mesh, CC0, cut out by `source/extract_arm.py`) under a
  fitted glove (knuckle and finger pads, palm patch, fingertip pads, wrist strap) and a sleeve (folds, trim band,
  hemmed cuff), skinned to the figures' arm and finger bones. `Rifle_Hold` is solved against the rifle's mesh: the
  right hand wraps the grip with the index finger on the trigger and the thumb over the far side, the left cups the
  handguard, both elbows bent (a two-bone solve from a bladed stance's shoulders). Each finger joint curls until it
  touches, then a settling pass opens any joint, or backs the hand off, until no face of the arms is inside the
  rifle; the build stops without writing if any clipping is left. 38,740 triangles (budget 40,000), 4 materials.
  Not drawn yet (step 32).

## Decisions

- CQB length for the AEG (the owner asked for shorter, no length given): 15.4 cm off the barrel and handguard, the
  stock one position in; bore height, grip, magazine and sight line kept, so the figures and the view still fit.
- The hands start from a real human base mesh (MakeHuman, CC0) rather than hand-built shapes, so their proportions
  and knuckles are anatomical.
- Plain colours, no textures: `ReplicaPaint` overrides `Body`, `Furniture`, `Detail`, `Accent` and `Metal` with the
  scheme's colours, so detail lives in geometry and normals. Textures can come later if the owner wants wear.
- No brand marks or trademarked shapes: a generic carbine.
- The arms ship ahead of the code that draws them, so step 32 can start from them; they cost nothing until loaded.
- Clips baked at 60 fps; the importer samples them at 30 as before.

## Known issues

- The sleeve bunches a little at the elbows in the side view; it is hidden in the first-person view.
- The arms are posed for the AEG Rifle only; the pistols and the rifle get their own holds when step 32 draws the
  arms. A foregrip fitted under the handguard would sit where the left hand cups it.
- The Sniper Rifle is still the AEG-based placeholder; the bolt-action model from the owner's new photos is the next
  batch.
