Task: SL1 · Sunlit Concrete: the light, grade and paint
Attempt: 2 of 4
Head: 67bf78b (gdlint and changelog passed on it; since b2ae737 only comments, one test, docs and the reports changed)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
Evidence for attempt 1's failures, now passing:
4. The look_paint asserts would fail if look_paint were removed. test_look.gd:169-176 checks that the include defines look_paint from the global look_paint_saturation, and that each of the four look shaders draws `ALBEDO = look_paint(`.
7. The stale comments are rewritten to Sunlit Concrete: look_light.gdshaderinc:1-7, map_style.gd:147 and :152 (grass), site_look.gd:141-142 (grit 0.6).
8. docs/KNOWN_ISSUES.md:16-18 has the three rows: the roof (until SL3), model wear (SL2) and grit on Low (playtest).
Gate: pipeline/out/performance.md is now SL1's report, Pass with the Low advisory, reviewed at e8aada2. No game logic changed since then, only comments. QA Pass (584cbf1).
Nit (non-blocking, fix in passing): the new comment lines run past the 120-column house wrap, at look_light.gdshaderinc:7 (181) and site_look.gd:142 (131).
Owner should test in the game:
- Depot's back racks and the gap behind the green container go near-black: can you still spot a bot there?
- Team blue and orange on figures still read as the loudest colours against the muted maps.
- Woodland's foliage and grass read as natural green, not khaki or pastel mint.
- The Street's meadow floors and pastel terraces at 60 % paint.
- A night map still looks right; the day retune must not leak into it.
- Low preset frame rate on Depot with grit 0.6.
