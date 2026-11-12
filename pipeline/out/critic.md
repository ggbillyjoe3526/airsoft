Task: SM5 · Subway's lamps and extras
Attempt: 3 of 4
Head: 5372b72 (= HEAD; targeted tests and gdlint passed on it, full tools/check.sh still running: this Retry stands either way)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
1. [judgment, measured on images] Strip lamp, proportions (a). My attempt-2 figures were wrong; the model follows
   them, and they are off the photo. I re-measured 121814 by pixel (x 300: body 97 to 129 px, cage 130 to 162 px,
   lamp 11 to 573 px). Photo against model (station_lamps.py:34-45):
   length:depth 8.6 vs 6.9 (-20 %); body:cage 1.0 vs 1.32 (+32 %); body:length 0.057 vs 0.082 (+44 %);
   cage:length 0.057 vs 0.063 (+10 %); clips 0.10/0.35/0.64/0.89 vs 0.10/0.35/0.65/0.90 (ok); hangers 0.22/0.76
   vs 0.25/0.75 (ok). sm5-5 shows it: the model's body is a heavy black box over half-height glow. The photo's
   diffuser is clear and almost as deep as the cage. The model's is a 0.045 m glowing slab in the top half.
   Clips are single diagonal sticks, not the photo's wire bails (b, minor).
1. [judgment] Tunnel lamp, construction (b). ARC went from 8 down to 6 (station_lamps.py:91) against attempt 2's
   "more segments". The front and front-quarter renders (sm5-1, sm5-5) show a 12-sided outline with flat 30-degree
   facets and a point at the top vertex. 122005's outline is smooth. The budget claim is wrong: the front is seen
   face on, so the outline's segments make the silhouette, not the bands. ARC 9 with two bands (body and front,
   smooth normals) costs 2x40 + cap 18 + bars 44 + lugs 6 = 148 of 150.
Passing now: the clip positions (your measure is right), tunnel glass inset in the front band (:124), bars
   ending inside the rim, lugs, the 6 % height:width match, both in-game panels.
Must-fix for the next attempt:
- strip_lamp: body 0.09 m from top to the lip's foot, cage 0.09 m under it (0.18 m, 8.4 to 1 at 1.52 m). A diffuser
  about 0.08 m deep that fills the cage, with the wires still clear of it, drawn so the bays read as glass in a cage
  rather than nine white tiles. Clips as a wire loop (two legs and a cross bar) over the lip. Re-render sm5-5 from
  level (0 degrees down) so the panel is a true side view next to 121814.
- tunnel_lamp: ARC 9 (or the most that fits), two bands, the top on an edge midpoint, not a vertex. If 150
  triangles cannot hold a smooth outline and the five-bar cage, ask the owner before cutting a bar.
- Nit (7): station_lamps.py:96-98. BAR_TURN lost its comment, which landed on LUG_H's line.
Owner should test in the game:
- Look up at a station strip lamp from 2 to 3 m: does it read as a slim caged batten, not a black beam?
- Walk a running tunnel past a bulkhead lamp at 1 to 2 m: does its outline look round, not polygonal?
- The tunnel lamps' glow against the dark wall: readable but not a glare spot?
