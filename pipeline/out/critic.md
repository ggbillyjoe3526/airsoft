Task: BL3 · AEG Rifle rework (owner's five fixes, 2026-11-05)
Attempt: 4 of 4
Head: bb48a2c + uncommitted working tree (aeg.glb = scratchpad aeg2/v21.glb, byte-identical); targeted GUT tests only
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept. Reports: QA (qa.md) BL3 Pass on v20, which v21 changes only by the back strap, the rail's rear
0.2 mm and the T's front 0.2 mm (re-measured below). Performance (performance.md) BL3 Pass on v21: 39,816 tris in the
hands; 12 meshes, 26 primitives, 7 materials. The owner called the earlier renders "Perfect" (06:47).
Measured on the photo vs v21 (fit 1425 px/m; crit2/grp.py, trg.py, ch.py, crit3/cop.py; crit4/ = scratchpad/crit4/):
- Charging handle ✓: 0 overlapping triangle pairs at rest and at every pull to 0.05. 3.9 mm of air under the T over
  the tower and the stock, 1.4 mm under the shaft. The T's front stands 0.2 mm clear of the upper's back. It reads
  free at rest and fully pulled.
- Trigger ✓: at z -0.012 the blade spans y -0.0058..-0.0104 vs the photo's -0.0053..-0.0107. It faces the photo's
  way, mid-guard.
- Grip ✓: front within 0.7 mm from z -0.012 to -0.072 (finger groove -0.0389 vs -0.0389, swell -0.0375 vs -0.0368).
  Widths within 1.0 mm from z -0.030 down. Back within 0.9 mm from z -0.030 to -0.072; at the very top (z -0.012) it
  is 2.3 mm behind (43.5 vs 41.2 mm, +6 %). Heel -0.1054 vs -0.1047. Foot 2.3 mm short (-2 % of the grip's depth).
- Back strap ✓: smooth from the lower's tail down. In crit4/j_closeL.png and crit4/g_closeR.png (same views as round
  3) the ridge and the pinch are gone; what is left is the moulded edge where the lower's flank meets the grip.
- Coplanar faces ✓: crit3/cop.py finds 10 overlaps on v20 and 0 on v21 in the receiver's rear. The black bars under
  the T are gone (crit4/s_cB.png).
- Mag well, rail, overall length: unchanged since round 1, which passed them. Panels as in round 3 (passed).
Failed checks: none.
Non-blocking, for KNOWN_ISSUES or a later polish pass (judgment):
- The castle nut and the buffer tube's end cap show 20-24 facets on their rims in close-ups. Recorded as a known issue;
  the hands budget has 184 triangles spare.
- The grip panels' bottom corners are 2-segment chamfers at ZOOM 0.2 (crit3/f_closeR.png).
- The sniper has only 64 triangles spare (performance advisory): any growth of the AEG body pushes it over.
Owner should test in the game:
- Inspect: the charging handle slides back with air under it and returns flush to the upper.
- First person: no flicker on the receiver's back under the charging handle.
- First-person hold: the finger lands on the trigger blade mid-guard, the tip curling forward.
- Inspect turn: the back of the grip flows down from the receiver with no ridge, pinch or ledge.
