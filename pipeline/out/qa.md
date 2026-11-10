Task: RW1 · QA commit 65cff16 · Verdict: Pass

Blocking: none; no bugs found in the change.
Advisory (no KNOWN_ISSUES row): replica_paint.gd's worn cache is keyed by the plain material's and the mask's
instance ids; both clear paths (materials() at MAX_SETS, clear()) also clear `_worn`, so a reused id can't return a
stale material. If anyone later clears `_sets` alone, the risk comes back.

Checked by test or by reading:
- Customise turntable repaint: paint swap, realistic toggle and back reuse the same worn material; worn=false
  repaints plain.
- OWN paint (Cyber) builds no worn material on any model; sniper and cyber carry no mask and stay plain.
- clear() mid-match: a live replica keeps its worn material; a later apply builds a new one.
- Depth press: the pressed copy stays worn (albedo, mask, z_clip_scale), the shared one unpressed, one copy each.
- Figures and mag toss plain (worn=false); menu pictures and turntable worn, figure meshes on the mask's clean corner.
- Ten repeat applies build no extra worn materials; all twelve paints in both modes stay within MAX_WORN.

Tests added (tests/unit/test_replica_wear.gd, 7 of its 15): repaint swap and back to plain, no duplicate worn
materials (both checked against a stubbed cache: they fail), own paint unworn, clean models plain under any paint,
cache clear keeps a live worn paint, cache bounded, pressed copy keeps colour and mask. 15/15, 396 asserts.

Could not test (needs a display or a person): how the wear looks in play, the first-use compile hitch, look_wear 0,
the turntable and menu pictures in a viewport.
