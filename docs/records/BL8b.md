# BL8b · The attachments' detail pass and the owner's three fixes

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | part tests (11 files) | Retry 5/8 (performance Pass) | laser hung under the frame on a daylight slit, stray grooves; variable scope's neck tapered; vertical grip 17% too tall for its photos; rifle silencer's triangles spent on segments, not detail; no tests for the fixes |
| 2026-11-05 | 2 | Claude (build thread) | part tests (7 files) | Retry 7/8 (QA Pass) | a stray stub under the variable scope; the vertical grip's stipple washed out by smooth shading; the angled grip's serrations buried in its body; the laser's seam notched its outline; the 2x's height the owner's call |
| 2026-11-05 | 3 | Claude (build thread) | part tests (7 files) | pending | – |

## What changed

The owner's rule of 2026-11-05 ("as much detail as possible within the budgets … 38,000 of 40,000 would be
reasonable") applied to the BL8 attachments (10,000 triangles each), and his three fixes the same day. All in
`tools/blender/parts/attachments.py`; the files rebuilt by it, `fit_parts.py` and `sniper.py`.

- **Detail pass:** every part now spends 85 to 99.8% of its budget on smoother rounds, softer edges and finer texture.
  - Silencers: rounded end caps, seam grooves, a stepped front face, a bore with a baffle, a threaded insert behind.
    The pistol's has a finer knurled collar (100 around) and a thread.
  - Torch: a parabolic reflector, a smoother body and head, latch ribs and paddle lines.
  - Laser, red dot, 2x scope: smoother lathes, fillets and dials; finer turret ridges.
  - Vertical grip: the body lofted through a curve of its rings (48 around), a finer scattered stipple, rounder
    edges. Angled grip: a smoother sweep and pockets, 40 finer serrations, 16 teeth, a rounder clamp.
- **Laser (the owner: no cylinder standing out; the laser flush inside the attachment):** one closed housing from the
  clamp to its front face, its top up against the rail, the emitter set in the face behind a short bright bezel, its
  glass 1.4 mm in. A seam round the front cap, grip ribs on its flanks, a switch pad on the left, the windage wheel
  in the right side, hex sockets in the cross screws.
- **2x scope (the owner: less tall, clear of the rifles' iron sights):** the axis 10 mm lower (46 to 36 mm over the
  rail, the owner's pick on a decision card), the hinged mount shortened under it: about 15% less tall overall.
- **Variable scope (the owner: a little smaller):** 10% smaller; its clamp and neck keep the rail's section and are
  shortened with it.
- **Vertical grip:** 15% shorter below its flared top, to the photos' height against the clamp (critic); its stipple
  crisp, seeded studs turned at random.
- **Angled grip:** 30 saw-tooth serrations, 1.4 mm tall, down the lower sweep, and the raked front's teeth, both now
  standing out of the body (they were sunk into it), so they break the outline as on the photo; the X's ends clear
  the pocket walls.
- **Variable scope's objective:** its bore and glass (14.6 mm) now sit inside the belly that rises to the front; the
  old 17 mm bore broke through underneath and its glass ring hung below as a stub.
- **Rifle silencer:** a knurled coupling band at the back, its round at 96 segments (critic: detail, not density).

| Part | Triangles before | after |
|---|---|---|
| Red dot | 5,510 | 9,388 |
| 2x scope | 6,388 | 9,628 |
| Variable scope | 9,960 | 9,984 |
| Vertical grip | 5,192 | 8,508 |
| Angled grip | 4,296 | 8,852 |
| Rifle silencer / pistol silencer | 1,886 / 3,096 | 9,564 / 9,698 |
| Laser | 4,926 | 9,308 |
| Torch (GBB Pistol and AEG / Cyber) | 3,406 / 3,066 | 9,278 / 8,810 |

## Decisions

- **The 2x's axis is 36 mm (the owner's pick):** at 40 its belly cleared the Sniper Rifle's rear leaf standing
  (19 mm, under the eyepiece) but the drop barely showed; at 36 the belly is 15.6 mm up. Both rifles' sights fold
  and hide under any optic (SightFold), so nothing meets it in play or in the menu pictures; a new test fits the 2x
  to the Sniper Rifle and checks both sights hide (`test_parts_in_play.gd`).
- **The variable scope shrinks towards its neck's top:** the scope is scaled by 0.9 about the mount 15 mm up; the
  clamp and neck are built apart and only shortened, keeping the photo's clamp-to-scope length. Its glass and eye
  distance in `viewmodel_config.gd` scale with it (glass 0.0646 to 0.0581 m back,
  radius 0.0122 to 0.011, eye 0.1728 to 0.1555), so the aimed view through it looks as before.
- **The laser's front is 30 mm ahead of the clamp's middle:** the old tube reached 37; the housing ends about 4 mm
  ahead of the GBB Pistol's slide.
- **The rifle silencer's knurl shades smooth** (its points share their corners) and the vertical grip spends 85% of
  its budget: the AEG's parts file holds every AEG part and stands at 1.94 MB of its 2 MiB cap, so the grip's flat
  stipple (crisp, as the critic asked) and the cap set the grip's count, not the 95% rule.
- **Tests for the three fixes** (`test_attachment_models.gd`): the laser's front 4 mm is the housing's full width
  with the emitter just inside; the 2x stands under 66 mm with its sight line at 36 mm; the variable scope is 120 to
  135 mm long.

## Known issues left

- The AEG's parts file is at 1.94 MB of its 2 MiB cap: more detail in it needs a lighter export or a split file.
- Every optic (the 2x now too) overlaps a rear sight leaf where it would stand; the leaves hide under any optic
  (SightFold), as before.
- The Cyber's torch spends 88% of its budget: its flush clamp drops the jaws the other torch has.
