# BL8b · The attachments' detail pass and the owner's three fixes

**Review:** 4 attempts, a fixes pass and the owner's change · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | part tests (11 files) | Retry 5/8 (performance Pass) | laser hung under the frame on a daylight slit, stray grooves; variable scope's neck tapered; vertical grip 17% too tall for its photos; rifle silencer's triangles spent on segments, not detail; no tests for the fixes |
| 2026-11-05 | 2 | Claude (build thread) | part tests (7 files) | Retry 7/8 (QA Pass) | a stray stub under the variable scope; the vertical grip's stipple washed out by smooth shading; the angled grip's serrations buried in its body; the laser's seam notched its outline; the 2x's height the owner's call |
| 2026-11-05 | 3 | Claude (build thread) | part tests (7 files) | Retry 6/8 | the laser's grip lines and windage wheel stood off its faces; the rifle silencer's smooth knurl didn't read; a stale Known issues row |
| 2026-11-05 | 4 | Claude (build thread) | part tests (7 files); tools/check.sh | Retry 6/8 (QA Pass, performance Pass) | the variable scope sat high on its neck (shrunk about 15 mm up, so the 20 mm under its tube kept its height); the Cyber's torch at 88% of its budget; the 2x's drop stated as 15% (13% measured); no known-issue row for the AEG file's cap |
| 2026-11-05 | 4, fixes | Claude (build thread) | part tests (3 files, 40); tools/check.sh | Accept 8/8 (confirming attempt 4's four fixes only) | – |
| 2026-11-05 | owner's change | Claude (build thread) | part tests (3 files, 40); tools/check.sh | Accept 8/8 (the lowered 2x) | – (the owner: the 2x as low as possible) |

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
  glass 1.4 mm in. A seam down the front cap's flanks, grip ribs on them, a switch pad with grip lines on the left,
  the windage wheel on its hub in a panel let into the right side, hex sockets in the cross screws, the elevation
  screw nearly flush underneath.
- **2x scope (the owner: less tall, clear of the rifles' iron sights; then "as much as possible"):** the axis 20 mm
  lower (46 to 26 mm over the rail), the hinged mount cut down to a thin plate and a saddle, its knuckle tucked
  under the body's flank: 25% less tall overall (79 to 59 mm).
- **Variable scope (the owner: a little smaller):** 10% smaller, shrunk towards the rail's face so it sits as low on
  its neck as on the photo (sight line 30.8 to 29.3 mm); its clamp and neck keep the rail's section and are
  shortened with it.
- **Vertical grip:** 15% shorter below its flared top, to the photos' height against the clamp (critic); its stipple
  crisp, seeded studs turned at random.
- **Angled grip:** 30 saw-tooth serrations, 1.4 mm tall, down the lower sweep, and the raked front's teeth, both now
  standing out of the body (they were sunk into it), so they break the outline as on the photo; the X's ends clear
  the pocket walls.
- **Variable scope's objective:** its bore and glass (14.6 mm) now sit inside the belly that rises to the front; the
  old 17 mm bore broke through underneath and its glass ring hung below as a stub.
- **Rifle silencer:** a coarse, hard-edged knurled coupling at the back and two grip grooves on the front cap, its
  round at 96 segments (critic: detail that reads, not density).

| Part | Triangles before | after |
|---|---|---|
| Red dot | 5,510 | 9,388 |
| 2x scope | 6,388 | 9,424 |
| Variable scope | 9,960 | 9,984 |
| Vertical grip | 5,192 | 8,508 |
| Angled grip | 4,296 | 8,852 |
| Rifle silencer / pistol silencer | 1,886 / 3,096 | 9,532 / 9,698 |
| Laser | 4,926 | 9,320 |
| Torch (GBB Pistol and AEG / Cyber) | 3,406 / 3,066 | 9,278 / 9,290 |

## Decisions

- **The 2x's axis is 26 mm, as low as its mount goes:** the owner picked 36 on a decision card, then asked for
  as low as possible with nothing in the way of the view. Both rifles' sights come off completely under any optic
  (IronSights), so they never stand in front of it in play or in the menu pictures. At first the AEG's receiver set
  the floor (its rear sight's base, 15 mm over the rail, cut the glass's lower edge below 25 mm); since GS2's smaller
  irons come off completely, rays from the aimed eye reach the whole glass down to a 16 mm axis on both rifles, so
  the floor is now the mount: at 26 the belly rests 0.6 mm over the clamp's top.
  At 26 the belly is 5.6 mm over the rail; a new test fits the 2x
  to the Sniper Rifle and checks both sights hide (`test_parts_in_play.gd`).
- **The variable scope shrinks towards the rail's face:** the scope is scaled by 0.9 about the rail's face; the
  clamp and neck are built apart and only shortened, keeping the photo's clamp-to-scope length. Its glass and eye
  distance in `viewmodel_config.gd` scale with it (glass 0.0646 to 0.0581 m back,
  radius 0.0122 to 0.011, eye 0.1728 to 0.1555), so the aimed view through it looks as before.
- **The laser's front is 30 mm ahead of the clamp's middle:** the old tube reached 37; the housing ends about 4 mm
  ahead of the GBB Pistol's slide.
- **The vertical grip spends 85% of its budget:** the AEG's parts file holds every AEG part and stands at 2.00 MB of
  its 2 MiB cap (1,998,324 of 2,097,152 bytes); hard-edged detail (the grip's crisp stipple, the silencer's knurl,
  as the critic asked) costs file size, so the cap (then 2 MiB), not the 95% rule, set the grip's count.
- **The parts files' cap rises from 2 to 3 MiB** (`test_attachment_models.gd`, `test_magazine_models.gd` and
  `docs/CC0_ASSETS.md` › Size limits; a default, not an owner ruling): the AEG's file holds the attachments (2.00 MB with this task), and the open magazine (MAG1, #209, about
  +0.40 MB) and barrel (BA1, #215, about +0.15 MB) tasks add their parts to the same file, about 2.55 MB together, so
  under 2 MiB whichever merged last would fail. 0.5 MB more is nothing against the install's 500 MB budget.
- **Tests for the three fixes** (`test_attachment_models.gd`): the laser's front 4 mm is the housing's full width
  with the emitter just inside; the 2x stands under 56 mm with its sight line at 26 mm; the variable scope is 120 to
  135 mm long, its sight line under 30 mm.

## Known issues left

- The AEG's parts file is 2.83 MB with the magazines (MAG1), barrels (BA1) and figures' part copies (TP1), 90% of
  its new 3 MiB cap; a quantised export (positions and normals) would roughly halve every parts file if size ever matters.
- Every optic (the 2x now too) overlaps a rear sight leaf where it would stand; the sights come off under any optic
  (IronSights), as before.
- The Cyber's torch spends its missing jaws' triangles on a ridged grip round the bezel (9,290).
