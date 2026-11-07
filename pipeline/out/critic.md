Task: BP7 · Part N: figures (A5, A2 68 and 78, trial rows 15, 17, 19, 55, row 69 "Glow")
Attempt: 4 of 4
Head: 0765d76 (--import, then 7 targeted GUT files 111/111 pass; tools/check.sh not run per brief)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking judgment fail). This holds only if QA's and the performance agent's reports
pass (I wasn't given either) and tools/check.sh is green on the head merged with main, which has moved to b4a1d5c.
Failed check, with evidence:
8. [judgment] The night load cost isn't in KNOWN_ISSUES. Each figure takes about 14 ms more to set up at night
   (ReplicaParts.take), about 150 ms a match load. The record says "Not a row, can wait", but a can-wait cost needs
   its row. The record's "main's WalkOff keys Shoulder_L too" is half true. Main's glb has no WalkOff Shoulder_L
   channel (57 channels; also absent when loaded at runtime with GLTFDocument). Godot's editor import adds one: I
   imported main's human.glb with the project's .import options and got track 57, at 12.0° from Idle. So the worker
   is right in-game and my attempt-3 note was right for the file; say which.
Against the attempt-3 must-fix list (all met):
- Far version: no torch. fars stay 3 to 3 in the test log, built by HeldMerge.merged_without (held_merge.gd +60).
- Holster: _fit_torches (figure_view.gd +664) swaps in the bare mesh; the test checks the surfaces and that nothing
  glows. The new picture shows it. The swap runs once a pose, with no allocation; it changes the mesh only on a
  change.
- Draws: the rifle +2 (its Rubber shares the replica's through share_own_paint), the pistol +3 in hand, +0 far.
  Logged by the test and in a new KNOWN_ISSUES document row: headless 235 to 257 mid-field; Forward+ on lavapipe at
  the spawn 133 to 143 (night lighting; the torches are past the far line there). Forward+ with every bot close is
  not measured: that's the owner's PC check, and the row says so.
- Beam: torch_beams.gd +142 starts at FigureView.lens_position (the front face of the torch's box), with a test.
  Presentation only.
- Row 15 test: 18.3 ± 1° for HitCall and WalkOff on both kinds. It fails on main: my editor import of main's glb
  gives 11.9° and 12.0°. The head's 18.3 is 14.0 past main's call key, so it agrees with call.py's -14° and
  KNOWN_ISSUES.
- The "about 2" comment is corrected.
- Radio picture re-shot at 0.27 m: no seam or facet before or after. The torch picture is updated and correct.
Carried from earlier attempts and still sound: robot.glb compaction is byte-clean; the contact ray, cone and thrown
magazine are presentation only with no per-frame allocation; body.py's shoulder weights are untouched.
Owner should test in the game:
- A night map with a full field: frame time and draws against a day map, on Forward+ on your PC.
- A bot at night, close: the torch on its rifle, the LED dot, and the beam leaving the lens.
- A bot at night switching to its pistol and back: the torch appears in the hand and not in the holster.
- The hit call and walk off from the front: the shirt patch by the strap (row 15, narrowed).
- Sniper Rifle at the hip: the cant, and the clack at 1.25 s (with the M150, 0.14 s early).
- Low: a ramp and a ledge drop (the shadow lies on the slope, then on the floor below).
