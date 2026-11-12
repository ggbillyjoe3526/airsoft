Task: SM5 · Subway's lamps and extras
Attempt: 4 of 4
Head: 877636a (= HEAD; targeted tests and gdlint passed on it, full tools/check.sh still running)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment). Check 1 fails, so no auto-accept: this goes to the owner.
Failed checks, with evidence:
1. [judgment, on images] Strip lamp, proportions (a) now pass. Measured by pixel, photo 121814 vs sm5-5's level render:
   length:depth 8.6 vs 8.2 (-5 %); body:cage 1.03 vs 0.98 (-5 %); body:length 0.059 vs 0.060; cage:length 0.057 vs
   0.062 (+8 %); hangers 0.23/0.78 vs 0.25/0.75; clips as before. The bails, the hooks on plates and the level view are done.
1. [judgment] Tunnel lamp, construction (b). My attempt-3 "two bands" fix caused this. The glass is now two flat
   planes, the front ring (r 0.052, z 0.085) and the side band to the rim (r 0.0745, z 0.026), folded on one hard
   crease (station_lamps.py:104,127-136). sm5-1's front-quarter view shows a glazed box corner where 121940 and
   122005 show a round barrel. A player walking a tunnel sees these lamps from that oblique angle.
1. [judgment] Tunnel lamp, (b). The glass's top corners show white slivers above the top bar (sm5-1 front, at the
   bar ends). The glass runs to y ±S = ±0.0675 but the outer bars sit at ±0.065 (:106), so the glass shows past them.
1. [judgment] Strip lamp, (d), minor. In the level view the bays still read as nine opaque slate panes, not
   121814's clear lens. The body and lip end flush (:58 prism over ±HALF), but the photo's lip overhangs each end by
   about 0.03 m (lamp 11 to 573 px, body 22 to 570). In the game (shot 11) the glow hides the panes; the lip does not.
Passing: proportions of both lamps, ARC 9 outline (front shoulders faintly polygonal at 2x zoom, acceptable at
   150), bars ending in the rim, lugs, BAR_TURN nit, in-game shots 11 and 12, the extras.
Must-fix (for the owner's call, or a re-run):
- tunnel_lamp: round the glass at no triangle cost. Widen the front ring to about r 0.064 at z 0.08 so the fold
  is shallow, or split only the two glass side faces with a bulged mid-ring (+4 triangles: pay for them by turning the
  pentagon lugs into triangles, -2 each). Set the outer BARS to ±0.0675 (or end the glass at ±0.065) so the bars
  cover the glass's edge.
- strip_lamp: extend the lip 0.03 m past each end of the body. Make the glass paler and lighter so the bays read as
  clear, and show the wires through it.
Owner should test in the game:
- Walk a running tunnel past a bulkhead lamp at 1 to 2 m, looking at it obliquely: round glass, or a box corner?
- Look up at a station strip lamp from 2 to 3 m: a slim caged batten, or only a glowing bar?
- The tunnel lamps' glow on the dark wall: readable, not a glare spot?
