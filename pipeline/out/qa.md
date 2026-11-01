Task: ST2 · QA commit 37731e1 (tests in head) · Verdict: Pass

Re-check at head 37731e1 (no code changed since 4718e15).
- The earlier blocker is fixed: changelog.d/the-street.md drops the stale blocks line, and changelog.d/the-street-dressed.md
  (plus a FEATURES line) says the railings, fences, hedges, kiosks, bus shelter and roadworks are still blocks.
- tools/changelog.sh check passes; tools/wiki.py check passes (25 pages).
- test_st2_qa 3/3, 261 asserts, 0.5 s. Earlier at 4718e15: test_props 18/18, test_street 5/5, test_st1_qa 9/9, test_look 16/16.
- Advisory unchanged: FIT stretches models non-uniformly (skip 2.3x, settee 2.1x, lamps and trunks thin posts); look needs a display.
- Not run: full suite, tools/check.sh, match guards, smoke test. Needs a display: how the stretched props look, team-colour reads
  by day and night, vehicle draw cost with shadows (performance agent).
