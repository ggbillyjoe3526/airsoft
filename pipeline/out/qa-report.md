Task: none (MQ1B) · QA commit <none, uncommitted> · Verdict: Pass

Attempt 3 re-verification of 7499a89 (rounder tang, shorter FRAME_SPINE, closed cell ribs, studio shadow change).

Blocking: none. Advisory: none new.

Checks
1. tests/unit/test_mq1b_qa.gd: 8/8 pass (41 asserts). tests/unit/test_cyber_grip.gd: 3/3 pass (44 asserts). Both run alone on the committed glb with -gconfig=.
2. Spine and web through the rounder tang: tests/unit/test_cyber_grip.gd:84 reads the rearmost point of every Body vertex (spine, web and grip together) at seven heights from -0.03 to -0.09 m, and holds them to a straight line within 0.8 mm. The rebuilt glb passes, so no spine or web vertex pokes out behind the back strap there. Not covered: Body points above -0.03 m (the tang's notch and above). The 7499a89 change touches this region and I did not test it.
   The cell and pad stay inside the grip's skin at rest and ride the Magazine bone (so they leave on Reload): tests/unit/test_mq1b_qa.gd:64, :135 and :156 pass on the rebuilt glb with the closed ribs.
3. Model studio under xvfb at the three poses (cyber at pitch +12, cyber at 0, aeg at -20): rendered a.png, b.png and c.png with no script errors. The only ERROR lines are the sandbox's Vulkan failure (VK_KHR_surface missing, falls back to OpenGL) and ALSA, both environmental. I did not look at the images.

Tests added or changed: none this attempt. No real gap found. The earlier 8 tests still fail without their features, as checked in attempt 2.

Counts: 11 tests, 85 asserts, a few seconds each.

Not tested: how the shadow-map and far-plane change looks (the images need an owner's eye on a real GPU). I did not run tools/check.sh, as asked.
