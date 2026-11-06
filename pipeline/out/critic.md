Task: none · BP5 part 2, performance
Attempt: 1 of 4
Head: a7c1586 (checks passed on it; code unchanged since 7799f56)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 6/8 → Retry (judgment)
Failed checks, with evidence (file:line, one or two lines each, each marked measured or judgment):
1. [judgment] The owner's bar is "optimise without losing quality" (BP5.md:16). The unseen stride (figure_view.gd:364)
   costs quality to save a measured ~0.15 ms. On Medium and up, where sun_shadows is on (data/graphics.md:44), an
   off-view figure's shadow in view poses at 30 Hz, and the record says so itself (BP5.md:72). Also, `seen` is only
   re-read every hold_view_stride (4) frames (figure_view.gd:349-351), so a figure turned into view can stay on
   half-rate posing for up to 3 frames. "In view again they are posed at once" (BP5.md:72) and "only their shadows
   show it" (changelog) are false, and the new test has to step hold_view_stride frames before `seen` flips
   (test_bp5_perf.gd:53). My bench (woodland 8v8, 30 s, interleaved, head vs unseen_stride=1, two runs each): frame
   mean 1.28/1.41 vs 1.55/1.44 ms, so about 0.15 ms. That is a third to half of the "0.3 to 0.5 ms a frame" written
   into the code comment (figure_config.gd:88), which no run backs (perf's own frame deltas are 0.03 to 0.2 ms).
8. [judgment] The player-facing claim "fewer slow steps on Woodland at 8v8" (changelog.d/bp5-performance.md:2)
   rests on 8 vs 2 frames over 16.7 ms in 9,600 (BP5.md:63). The same paragraph calls the worst ticks single spikes
   either way, the head's worst (20.61) is above main's, and my runs show 1/1 (head) vs 1/0 (stride 1). That is noise.
   Mean and p95 are "within main's own spread" by the record's own words, so the honest gain is "not measurable at
   8v8 headless". The record also doesn't split the gain by change: nothing shows how many teammates the
   _body_in_line quick test (bot_combat.gd:370-375) actually rejects. It adds a may_touch to every teammate near the
   line, and its widest room (margin + (mate_speed + speed) x flight to dist) may reject few. "Profile before
   optimising" (CLAUDE.md §8).
Passed, briefly: may_touch's sphere is a sound superset (|M-C| <= half + up + r), costs about 10 flops, and saves 3
   calls per far body per BB (hitbox.gd:155-163). It is worth it, but its only test is an equivalence check that can't
   show the early-out ever fires. QA's monotonic-flight reasoning holds. No per-tick allocation in any hunk. No
   contract touched. unseen_stride is data like far_stride. Tests 2/2 and 4/4 (86 asserts) pass.
Must-fix for the next attempt: (a) Either drop the unseen stride, or apply it only where it can't be seen: sun
   shadows off (Low) or the figure beyond the shadow range. Re-read `seen` at once when the camera turns more than the
   view margin, or pose every frame whenever `seen` is stale. (b) Put the measured number in figure_config.gd:88
   (about 0.15 ms headless) or remove it. (c) Rewrite the changelog line and BP5.md:63 to the honest result: a small
   view-frame saving, tick within noise, no "fewer slow steps". (d) Count the quick test's rejections on one bench
   run and record it, or drop the quick test if it skips few.
Owner should test in the game (at most 6, one line each):
- Medium or High, low sun: a teammate running just off screen to your side. Do its shadow's legs step or stutter?
- Flick 180° onto a running bot: any one-frame hitch in its legs as it comes into view?
- Low preset: no visible change anywhere (no shadows to show the stride).
- Woodland 8v8 on your machine: any frame-time difference you can feel against main?
