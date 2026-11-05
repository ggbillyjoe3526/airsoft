# BL6 · Blender: the Cyber Pistol

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (BL6 thread) | CI | art review: Retry (round 1, 11 fixes made), Accept (round 2, its 4 small fixes made) | – |

## What changed

- **The Cyber Pistol's model** (`assets/models/replicas/cyber.glb`), rebuilt by the new
  `tools/blender/replicas/cyber.py` (bpy 5.2.3, the `hardsurface.py` helpers). The owner (2026-11-05 07:28): "quite
  happy with the current cyber pistol, so use that as a starting point but improve it with the help of the reference
  images and make it higher quality". So the old model's layout, silhouette and own colours stay (white slab, near-black
  cell in the grip, cyan lines, pink core, gunmetal), and the reference photos (`ref_images.zip`,
  `replicas/cyber_pistol`) give the detail: a front shroud with four trapezoid teeth along its foot, an inset panel with
  three glowing slashes and a stepped lower half; a muzzle block with grooves, a chamfered face and the barrel standing
  out of it; a slide with the pink core behind bars on both sides and on top, cocking grooves and a glowing line; a
  rear block with a hex plate and vents, a lower skirt and a finned rear cap with glowing rings; an angular trigger
  guard and a deeper curved trigger with a safety blade; a dark selector housing with the track and three fire-mode
  lights; a ribbed release, a takedown lever, screws and pins; a grip with front-strap serrations (the old teeth),
  back-strap grooves and windows showing the ribbed cell with its glowing ring; a stepped base pad.
- **Original design:** the photos show a well-known video-game prop, so only its detail vocabulary is used (no text, no
  logos, four trapezoid teeth instead of its three notches, the old model's hex plate and colours).
- **Contract kept** (docs/CC0_ASSETS.md › Replica models): the armature `CyberPistol` with the bones root, magazine,
  selector, slide and trigger at the old heads; the clips Fire (8 frames), Selector (12), Reload (66) and Inspect (120)
  at 60 fps with the old file's keys; the empties Muzzle, FrontSight, RearSight, MagWell, SlideBack and TorchMount at
  the old points (so `replicaParts/cyber.glb`'s torch is unchanged); the meshes Body, Slide, Trigger, Selector,
  Magazine and Figure; the materials CyberSlab, CyberFrame, CyberLine, CyberCore and CyberMetal with the old colours
  and glow. The old file's `Figure` node sat 0.3 m down (a leftover: the game resets the Figure's transform); the new one
  sits at the origin like the other replicas'.
- **Budget:** 31,292 triangles in the hands (40k limit), 240 in the figure version; 6 meshes, 5 materials, no
  textures. The build is deterministic (two runs give the same file).

## Defaults taken

- The rail under the front ends at y 92 mm, behind the shroud's lower front chamfer (the torch's clamp still fits).
- **Owner's review (2026-11-05 08:55-08:56):** "I love it!", then the trigger longer and the guard taller, "more like
  the original trigger and guard shape". So the trigger is the old model's curved blade (its outline, 2.4 mm longer:
  z -11 to -37) and the guard the old one's: a narrow loop in front (6.5 mm either side), a full-width web behind, the
  opening y 0.5 to 45.7 and z -16.5 to -40, 3 mm under the trigger's foot.
- **Owner's review (09:10):** "The trigger is leaning too far back." The blade now stands upright, its finger face
  hollow and its foot curling 1 mm forward of its root. The earlier pictures showed the importer's first frame of the Fire
  clip (trigger pulled 17°, slide back 14 mm), which made the lean look worse; the review renders now clear the pose.

## Verified

- The Cyber Pistol's tests (every test file that names it, plus parts in play): 317 of 317 passed on the first build.
- `tools/check.sh` (local): gdlint not installed here (CI runs it), changelog notes and wiki pass, unit tests part 2
  passes; parts 1 and 3 stopped at their local time limit (exit 124, a cloud session's known slowness while renders ran
  alongside); CI runs the whole suite.

## Play this

`docs/PLAYTEST.md` › The new Cyber Pistol model (BL6).
