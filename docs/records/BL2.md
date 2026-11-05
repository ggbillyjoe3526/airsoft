# BL2 · Blender batch 2: the GBB Pistol

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-04 | 1 | Claude (build thread) | checks green | Retry 7/8 (rounds 1 to 10, each fixed in turn) | measured differences from the photo |
| 2026-11-05 | 2 | Claude (build thread) | checks green | Accept 8/8 (rounds 11 to 13, after the owner's two looks) | – |

## What changed

- **The GBB Pistol's model** (`assets/models/replicas/pistol.glb`), rebuilt from the owner's reference photos
  (`ref_images.zip`, 2026-11-04) by `tools/blender/replicas/gbb.py` and matched to his main photo (a left-side view) by
  a measured overlay: the photo's pixels map to metres at 2951.6 px/m with the origin fitted on the old model's grip, so
  the figures' hold and the replica's place in the hand don't move. The side outline overlaps the photo's by 0.96 (0.985
  before the owner's proportion changes below). A compact striker pistol: a squared slide with rounded top corners,
  eleven rear serrations, a rear cover plate and a port with the barrel's hood and an extractor in its slot; a flush
  barrel and the guide rod's end in the nose; a wide rear sight with a U and a front sight with a dot set into its back
  (the `Accent` slot); a railed dust cover with a deep rail slot; a slim trigger guard filleted into the frame; a
  leaning, ribbed takedown tab in a narrow, shallow recess leaning with it, a ribbed slide stop over its recessed shelf,
  and the pins; a broad trigger with its safety blade; a raked grip lofted from the photo's front and back straps, with
  ribbed pads on the front strap's finger bumps, slanted grooves down the back strap wrapping onto the sides, a
  thumb-rest bowl over a raised rim, stippled side panels and a chamfered foot; a magazine release ribbed on the left
  with its plain end on the right; a magazine with a two-tier base plate (marks on its foot) and a front tongue. 39,638
  triangles in the hands (budget 40,000), its figure version 120, 7 materials.
- **Stippled panels.** The panels are thin shells over the grip's sides with a 256 px dimpled normal map in the
  `Stipple` material, the model's only texture (Godot extracts it beside the model as
  `pistol_stipple_normal.png`). `ReplicaPaint` leaves `Stipple` alone, so the panels keep their texture under every
  paint.
- **Same contract.** The armature `GBBPistol` with its five bones, the meshes Body, Slide, Trigger, Magazine,
  MagRelease and Figure, the seven empties and the four clips (Fire, Reload, Inspect, SlideLock) with the old
  timings. Moved with the photo's shapes: `Muzzle` and `ThreadEnd` (the flush barrel, 9.96 cm ahead), the sights
  (7.8 mm lower, the photo's slide height), `MagWell` (the photo's well, 2.7 cm further forward) and `RailMount` /
  `TorchMount` (under the slimmer dust cover, 3.4 mm higher). Each moving part's mesh is modelled about
  its bone's head, as before.
- **Parts** (`replicaParts/pistol.glb`, rebuilt by `gbb.py`): the extended magazine is the new magazine run on
  2.2 cm with a frame-coloured base pad, on the new `MagWell`; the silencer moved onto the new `ThreadEnd`; the
  laser and torch moved onto the new `RailMount`. `test_parts_in_play.gd` expects the magazine part at the new well.
- **The figures' pistol reload** (`magazineInHand` › `Pistol_Reload` in `human.json`, `robot.json`): the hand's
  new and old magazines moved so they match the pistol's own magazine again (all four under 0.1 mm off;
  `test_figure_hands.gd` checks the old one). `bot14.py` writes these from its own fit
  (`L_IN_MAG`), which still holds the old pistol's magazine, so a figures rebuild must refit them or keep these values.

## Decisions

- **Owner, 2026-11-05** (he reviewed the build: "almost perfect"): the takedown lever sits slightly recessed, the
  recess's walls curving smoothly into the frame; the slide is taller (its side's foot from photo py 99 to 108) and
  the body under it slimmer (the dust cover's underside from py 165 to 155), with the slide stop, takedown lever and
  rail moved down, to the proportions of his second photo (`/mnt/project-files/art/blender/batch2/`
  `william-ref-2026-11-05.jpg`). His main photo still governs everything else.
- **Owner, 2026-11-05, second look:** the takedown recess narrower and leaning parallel to the lever, as in his
  second photo (floor 27 by 29 px with 5 px soft walls easing into the side, lean 0.33 px per px, the photo's,
  and the lever narrowed to the photo's 7 px and leaning with it); the slide's face flush
  with the frame's nose (photo px 22, it was 25), per his markup
  (`/mnt/project-files/art/blender/batch2/william-nose-markup-2026-11-05.jpg`). The barrel's crown now stands
  0.7 mm proud of the face. The front sight is one piece: its white dot is set into the post's back face (it stood
  behind the post, owner 04:18).

- Generic shapes, no brand marks: the photo's logos and the maker's slide cuts are left off.
- The barrel sits flush with the slide's nose, as in the main photo.
- The grip-anchored mapping (the photo placed by the old grip) over a fresh seat: the figures and first-person hold
  keep working without re-solving the hands.
- The panels' stipple is a normal map, not geometry: thousands of dimples would break the triangle budget.
- The thumb rest is a bowl at most 1.3 mm deep, so the frame's wall stays over the magazine.
- The straps' ribs and grooves are cut into the grip, not modelled as raised pads; the stippled panels' mesh is coarse
  (the dimples are the texture) to keep the hands under 40,000 triangles.

## Known issues

- Small differences the critic left open: the front strap's ribs are finer than the photo's chunky ridges, the
  rail lacks the photo's second lip, the barrel's crown sits about 1.7 mm ahead of the
  photo's (0.7 mm proud of the slide's face).
