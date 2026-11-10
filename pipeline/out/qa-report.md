Task: RF1 · QA commit see git log · Verdict: Pass

Blocking: none. Advisory: none reproducible.

Tests added (tests/unit/test_rf1_qa.gd, 15 tests, 15 pass, ~10 s; raw output pipeline/out/qa/rf1_qa.txt):
- set_look holds lines/levels to the slider ends, before and after entering the tree, huge and negative input. Fails if the clamps are removed (levels would exceed 32 / go negative).
- pixel_size never below 1, zero/negative lines safe, 0 height safe. Fails without the maxi guards.
- resize: snap follows a changed window size and the connection is made/removed. Fails if size_changed is not connected.
- no lighting (setup(null)): builds and frees quietly, snap zeroed on exit.
- leaving the tree zeroes snap and disconnects size_changed.
- haze off restores a night map's own fog (begin/end/density/colour); a fog-less day map returns to no fog. Fails if retro_haze(false) did not call _own_haze.
- off and on in one frame: one filter, new haze stands, old one's exit does not leave snap zero or the haze off.
- lighting freed before the filter: no script error. Session freed with the filter up: no error.
- session toggled on/off/on four times in a row: never more than one RetroFilter, none when off, map haze back.
- save compatibility: old retro_pixels switch turns the filter on with new default lines/levels (old size/shades ignored); round trip; corrupt/out-of-range/missing values fall back to defaults.
- LINES default and ends sit on the Lines slider step.

Checks of "fails without the feature": the old keys/class do not exist in base 16a9b26, so these cannot compile or pass there; I did not mutate production code (not allowed).

Could not test (owner/display): how the PS1 look, wobble and swim actually look; Retro filter at 1080p/4K and in borderless/fullscreen; the global itself (not read back, it can stall the renderer: only RetroFilter.snap() is checked); a headless run has no real renderer so the shaders are not compiled by these tests.
Suite: not run whole (check.sh running elsewhere); this file only.
