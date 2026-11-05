Task: GT1 · QA commit d5e54eb · Verdict: Pass

Blocking: none.
Advisory:
- game/play/figures/figure_hands.gd set_bomb_meshes: it resets bomb_shown to NONE without hiding _bomb. A second set_bombs
  call while a bomb shows leaves it visible after the throw ends, since show_bomb(NONE) returns early. Not reachable now
  (PlaySession calls set_bombs once, after _build_bodies). Fix: hide _bomb and clear its mesh there. Pinned by a failing
  test (test_set_bombs_again_mid_throw_does_not_strand_a_shown_bomb); the commit carries one deliberately red test.

Tests added (tests/unit/test_figure_throw_qa.gd; the 8 are only checked against the same code, not against a stubbed-out feature, except where noted):
- bombs given before the body: bomb shows (the worker's set_body path; fails if set_body skipped set_bomb_meshes).
- rebuilt body (human to robot) mid-throw keeps drawing the bomb (fails without the set_body re-hand).
- hit mid-windup (status CALLING, hand stopped or left set): no bomb.
- far figure (200 m, far_stride): bomb shows, and is gone within a stride of the throw ending.
- hidden then shown mid-throw: bomb shows after the snap.
- readied FLASH then a thrown FLASH: same mesh, one bomb, visible.
- set_bombs twice mid-throw: FAILS (the advisory above).
- throws and body rebuilds: node count does not grow.
Existing test_figure_throw.gd: 7/7 pass. QA file: 7/8 (the advisory). Full suite and check.sh not run (running elsewhere).
Not tested: how the arms look (needs a display; tools/render_throw.gd), the PlaySession wiring itself (read: set_bombs is
after _build_bodies at play_session.gd:719-721, correct).
