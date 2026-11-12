Task: SM5 · Subway's lamps and extras
Attempt: 7 (past 4; review-cap ruling: keep fixing until the critic passes)
Head: 499786e (= HEAD; test_station_fixtures 8/8, test_sm5_qa 6/6 on it; full tools/check.sh unfinished when judged,
   its output file empty: this Accept holds only once it ends green on 499786e)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Attempt 6's must-fix, done:
1. [judgment, code and images] station_lamps.py:+157-159: face_toward([f[ARC], top_spine, f[0]], +y, "black") and
   [f[ARC+1], low_spine, f[n-1]], -y: both in their planes (stadium() puts f[0] and f[ARC] at y = S, f[ARC+1] and
   f[n-1] at -S, the spines at +-S), faced outward, black like the dome. sm5-1 front quarter: the glass's top edge
   meets the dome with no bright sliver, the bottom edge a solid black lip. New "front quarter from below" (-30 deg,
   station_render.py:+24): the lower wedge reads as a flat black lip under the glass, no grey background through it.
   150 of 150 triangles (sm5-1 header, record, ASSETS.md). Nothing else in the mesh changed (3 lines added).
Regressions: none seen. Front, front quarter and shot 12 (2 m, in game) as at attempt 6; the strip lamp untouched;
   subway.json and fixtures.py bounds unchanged (the triangles sit inside the old bounds). performance.md (Pass) still
   holds: two triangles, mesh only. Checks 2 to 8 as at attempt 6.
Still short of the owner's photos, not blocking at his 150-triangle budget: the lip triangles are flat-shaded beside
   the smooth dome, so from below the lower one reads as a hard facet; the front still reads as a ridged panel
   (chevron bars) more than 121940's barrel; the bars' cut ends show as light slivers past the right rim from below.
Must-fix for the next attempt: none (merge once tools/check.sh ends green on 499786e).
Owner should test in the game:
- Walk a running tunnel past a bulkhead lamp at 1 to 2 m, looking up and down at it: any gap at the glass's edges?
- The same lamp obliquely at 1 m: does the glass read round enough, or should model 32's 150-triangle budget rise?
- At 3 to 5 m: an oval caged bulkhead, no point top or bottom?
- Look up at a station strip lamp from 2 to 3 m: a slim caged batten with a lip past its ends?
- The tunnel lamps' glow on the dark wall: readable, not a glare spot?
