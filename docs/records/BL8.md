# BL8 · The attachments from the owner's photos

**Review:** 3 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | targeted tests pass (8 files, 122) | Retry 6/8 (QA Pass, performance Pass) | torch head too fat, its reflector unseen; silencers stubby; laser fluted, not knurled; angled grip's sweep kinked, no X or teeth; vertical grip's studs coarse; variable scope's eyepiece short, caps big; 2x glass flush; red dot on a tower |
| 2026-11-05 | 2 | Claude (build thread) | tools/check.sh green (4,752 tests) | Retry 7/8 (QA Pass) | pistol silencer too slim against its photo; torch head too short; vertical grip's top not flared, stipple a dot grid |
| 2026-11-05 | 3 | Claude (build thread) | part tests pass (10 files, 144); full check on the rebased head | Accept 8/8 (QA Pass, performance Pass) | – |

## What changed

Nine attachments rebuilt from the owner's photos (`ref_images.zip` › red_dot, 2x_scope, variable_scope,
vertical_grip, angled_grip, silencer, red_laser, weapon_torch) by one build script,
`tools/blender/parts/attachments.py`, into `assets/models/replicaParts/{aeg,pistol,cyber}.glb`; `sniper.py` then copies
the AEG's optics, grips, silencer and torch into the Sniper Rifle's file. Unbranded; detail is geometry (no textures).

- **Red dot:** a closed micro sight on a low riser, its hood canted at the front, a battery cap, dials and a clear
  red-tinted window. Sight line unchanged (30.5 mm over the rail).
- **2x scope:** a flip-to-side magnifier on a hinged mount, its objective set back behind a chamfered lip.
- **Variable scope:** the compact prism scope of the side photo, with its illumination dial, turrets, objective box
  with side rails and a fibre front sight along the top rail, and a rear aperture sight.
- **Grips:** a short vertical grip (flared top, stippled panels, 22 ribs a face) and a kinesthetic angled handstop
  (smooth sweep with fine serrations, toothed raked front, an X in each side pocket).
- **Silencers:** a plain black tube on the rifles; the pistol's the photo's stubby tube on a knurled collar.
- **Laser:** a diamond-knurled module in a rail block with a windage wheel (pistol rail).
- **Torch:** a compact pistol light with a polished reflector and an LED, on the AEG's right rail, the pistols' rails.
- Every part keeps its contract: its `_Figure`, `_SightLine`, `_Muzzle`, `_Beam` and `_UnderLaser` children, its
  origin on the replica's mount. The largest is the variable scope at 9,960 triangles (cap 10,000); files 0.1 to 1.3 MB.

## Decisions

- **Styles where a folder mixed several** (the owner's defaults rule: take one, say which): the micro red dot, the
  flip magnifier, the prism scope of the side photo, the stubby vertical grip, the kinesthetic angled grip, the plain
  tube silencer, the knurled laser in a block, the X300-style torch.
- **The red dot's rear deck stops at the window's bottom edge** (12.2 mm over the sight's base, 0.39 of the hood
  against the photo's about 0.5): any higher and it hides the lower half of the aimed glass (QA's ray test).
- **The red dot's eye distance is 0.15** (`viewmodel_config.gd`, was 0.136): the micro window is smaller than the old
  round one, so the eye sits a little further back to see all of it.
- **Parts stay in the replica's paint** (`Detail`, `Furniture`, `Metal`): every paint's Detail is a near-black, so the
  silencer and optics read black in play, and a painted kit stays one set. Glass, the fibre, the LED and the torch's
  reflector keep their own materials.
- **The Cyber's torch clamp sits flat under its rail**: the rebuilt Cyber's shroud flanks are flush with the rail, so
  nothing rises past the rail's face outside it.
- **The variable scope test** now checks the photo-based scope's length and budget instead of the old placeholder's.

## Known issues left

- The variable scope is 40 triangles under its 10,000 cap: any detail added must come out elsewhere.
- The parts' own materials (glass, fibre, LED) are not in the shader prewarm; the held replica's parts draw before
  play, but a first swap to the other slot might hitch (performance, advisory; the owner's Low-preset run).
