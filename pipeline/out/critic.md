Task: none (BP7 bots: rows 21, 39, 95, 64, 40, 41 narrowed, 45 and 38 narrowed) · bug pass
Attempt: 2 of 4
Head: bb6dbd2 (b6f8e55 + bb6dbd2 over c438d5a). Re-run here: test_mag_share, test_bp1_qa, test_bot_mag_share, test_mh3_qa 74/74.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (one non-blocking check failed). This needs QA and performance to pass again on bb6dbd2: both
passed c438d5a and are re-checking now.
Must-fix 1 (attempt 1), fixed:
- `toss_line_clear` and `MagShare.step` now both use `_path_meets` (game/sim/mag_share.gd @@ +240, +298). Both check
  the same `MagShareConfig.path_pieces` (4) chords of `flight_point`, from throw_point to catch_point. In flight each
  piece is checked once the toss passes its end. The bots' walk-up uses the same check. A toss allowed with nobody
  moving is caught.
- My attempt-1 probe re-run on bb6dbd2:
  - Lintel at 1.6 m: refused, not lost.
  - Crouched against 0.8 to 1.0 m cover: every case is now either allowed and caught, or refused. None is lost.
    0.9 m cover at 0.33 m is now refused: the chords are a little stricter than the old fine check, which is safe.
- The new test_mag_share case (lintels at 1.6, 1.9 and 2.1 m; crouch cover at 0.8 and 1.0 m) asserts "caught exactly
  when allowed". It would fail on c438d5a: the 1.6 m case was allowed and then lost.
test_bp1_qa (tests/unit/test_bp1_qa.gd @@ +146) changed with the rule; the test is not loosened:
- The old check asserted that a standing giver right up to 1.4 m cover could toss, by the eye line (1.62 m). Its hand
  is at 1.32 m, so under the flown path that toss would hit the cover and be lost. Refusing it is the fix itself.
- The original intent (from right up to cover, the toss passes over it) is kept by the new 1.2 m case, asserted true.
  Slab.ray reads `height` live, so the change takes effect. The test is stricter, not looser. The survey test in the
  same file (bots never parked) still passes.
Must-fix 2 (attempt 1), fixed:
- The note and the wiki now say "lost at the wall". The bomb line is now part of smoke-and-flash-bombs.md, where
  bombs are described.
- PLAYTEST.md:237 and the MAG_LOST comment are updated.
- The note now names the new limit in player words: under a low lintel, or crouched behind cover taller than your
  hand, the toss waits.
Failed check, with evidence:
8. [judgment] Two stale lines from row 64 (bombs leave from the hand now):
   - game/sim/README.md, grenades row: "0.3 s later the bomb leaves the eyes at 13 m/s".
   - game/sim/game_event.gd:43: GRENADE_THROW "from its eyes at position". Its position is the hand now
     (grenades.gd @@ +459).
   Fix both in passing. This doesn't block.
Notes: QA's MAX_NEAR note stands. A toss to a player behind a lintel is refused with the "get closer" line, which
names the wrong cause (that wording predates this branch).
Owner should test in the game (at most 6, one line each):
- Throw a smoke and a flash looking level, steeply up and down, and against a wall: does each leave your right hand?
- Follow me, then sprint off from a teammate 15 m back: does it close to about 7.5 m and keep pace without surging?
- Toss a mag over chest-high cover and from a crouch behind low cover: does refusing these feel fair, or too strict?
- Woodland at Hard: do bots near tall bushes watch the bush edges, and not stare at every bush?
- Run low beside a fighting teammate: does the asker take cover and stay there, or pop up to peek?
- With bot teammates on kits: is your side as strong as theirs, and do sniper teammates leave you short of mags?
