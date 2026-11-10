Task: RF1 · QA commit f83100f · Verdict: Pass

Blocking: none. Advisory: none.
Re-run at head 37039b7. test_rf1_qa.gd 19/19 pass (~12 s), test_dev_play.gd 10/10 pass (~64 s). Whole suite left to check.sh. Raw output pipeline/out/qa/.

Added (tests/unit/test_rf1_qa.gd, end of file):
- haze changed after build (site-dressed sky haze) is restored exactly after on, on again, off; off twice harmless. Fails if retro_haze held the preset or re-held the retro haze on a second on.
- haze off without on leaves the night fog untouched (no restore of an unset hold).
- _process with no camera is safe.
- a filter outside the tree does not process (the globals are touched only while it is up).
Earlier 15 tests (clamps, resize, no lighting, night fog back, one-frame off/on, freed lighting/session, toggling, saves) updated by the worker for held haze and still pass.

Not tested: the camera globals' values (reading globals can stall the renderer); how the look appears, other resolutions and window modes, shader compilation (need a display).
