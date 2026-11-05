Task: BL8b · QA on the attempt-2 worktree (head 724956a plus the BL8b changes, since rebased onto main as this branch) · Verdict: Pass

Blocking: none.

Part contracts
- test_attachment_models.gd 14/14 and test_at3_qa.gd 14/14 on that build: markers (_Figure, _SightLine, _Muzzle,
  _Beam, _UnderLaser), sight lines on their lenses, the laser's beam at its emitter, the new laser, 2x and variable
  scope tests.
- Read from the glb: the laser's Beam sits 0.1 mm ahead of its LaserLens (LZ_LENS_Y + 0.1).

Scaled viewmodel values (scopeVar)
- sv_shrink scales about the rail's face: the eyepiece glass lands at -64.6 x 0.9 = -58.14 mm; config 0.0581,
  eye 0.1728 x 0.9 = 0.1555, radius 0.0122 x 0.9 = 0.01098 (config 0.011, inside the 11.52 mm lens).
- The mount is built apart and only shortened (k 0.9), its section and bolts rail-sized; the neck (z 8 to 18) still
  overlaps the shrunk housing's underside (17.3 mm); the figure copy is shrunk the same way.

Budgets and sizes
- Every part under 10,000 triangles; every parts file under 2 MiB (the test pins 2 x 1024 x 1024).

Hard-coded old values
- No 46 mm 2x height or laser nose constant left in game/ or tests/; LZ_NOSE is gone.

Advisory
- The scope and laser in the viewmodel need the owner's eye: aimed through the variable scope, the glass should fill
  the lens with no clipping.
- Later attempts (3, 4: the 2x at 36 mm, the laser's pad and wheel, the silencer's knurl, the grip and serration
  changes) are geometry inside the same contracts; tools/check.sh on the final head covers them.

Verdict: Pass
