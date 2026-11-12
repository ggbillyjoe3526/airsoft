Task: SM5 · Subway's lamps and extras
Attempt: 6 (past 4; review-cap ruling: keep fixing until the critic passes)
Head: e3dfd73 (= HEAD; test_station_fixtures 8/8, test_sm5_qa 6/6 on it; full tools/check.sh still running when judged)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
1. [judgment, code and images] Tunnel lamp, construction (b): the raised glass opened a hole. The dome's front rungs
   stay flat at z 0.084 (station_lamps.py:+144-149, DOME :+107), but the glass now rises to SPINE 0.095 at y = +-S
   (:+154-156). Nothing closes the triangle f[ARC], top_spine, f[0] in the plane y = S (or its mirror at -S): a wedge
   116 mm wide, 11 mm deep at the middle. The outer bar (3.2 mm half width) hides it only head-on; sm5-1's front
   quarter shows a bright sliver along the glass's top edge and a dark notch along its bottom; the side view a sliver
   at the lower right. Seen from below or above at 1 to 2 m, as a player walking the tunnel does, you look into it.
Passing now: the side-glass split is gone; the lugs are blunt tabs (:+171-173), no spike on the front or in shot 12;
   the bars bend at the turn and over the spine and follow the glass. At 3 m (shot 12) it reads as a caged oval
   bulkhead. Proportions unchanged from attempt 4 (pass). The strip lamp, as at attempt 5. Checks 2 to 8: this commit
   touches only the Blender scripts, the .glb, fixtures.py's bounds row (z 0.102, the vertical bar's crest:
   0.0985 + 0.004) and the record. The wire `flat` option is additive; strip lamp callers keep `flat_ends`.
   pipeline/out/qa/sm5_qa.txt passes; performance.md (122ea50, Pass) still holds: mesh only, same budget.
Still short of 121940, not blocking at 150 triangles: the arc's bends are 63 deg at the dome ring and 22 deg at the
   spine, so the front quarter reads as a panel with a ridge (chevron bars), not a barrel; the vertical bar stands
   14 mm clear of the dome over its ends. Roundness at close range is limited by the owner's budget (model list #32).
Must-fix for the next attempt (tunnel_lamp only; 148 + 2 = 150):
- Close the two wedges: one triangle each, f[ARC], top_spine, f[0] at y = S and f[ARC+1], low_spine, f[n-1] at -S,
  painted black like the dome (the body's lip round the glass), faced outward along +-y. Re-render sm5-1's front
  quarter and a view from 30 deg below: no sliver or notch at the glass's top or bottom edge.
- Nothing else changes.
Owner should test in the game:
- Walk a running tunnel past a bulkhead lamp at 1 to 2 m, looking up and down at it: any gap at the glass's edges?
- The same lamp obliquely at 1 m: does the glass read round enough, or should model 32's 150-triangle budget rise?
- At 3 to 5 m: an oval caged bulkhead, no point top or bottom?
- Look up at a station strip lamp from 2 to 3 m: a slim caged batten with a lip past its ends?
- The tunnel lamps' glow on the dark wall: readable, not a glare spot?
