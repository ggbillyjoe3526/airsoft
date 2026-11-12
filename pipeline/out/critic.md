Task: SM5 · Subway's lamps and extras
Attempt: 10 (past 4; review-cap ruling: keep fixing until the critic passes), William's "Make the far trackside
   posters much larger"
Head: 21ad054 (= HEAD). Full tools/check.sh started on 21ad054 and NOT finished when judged (its output was empty);
   test_station_fixtures 8/8 and test_sm5_qa 13/13 ran on it. The diff touches no runtime script.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (merge only once tools/check.sh ends green; the verdict lapses if it fails)
Failed checks, with evidence: none.
Checked this attempt (git diff HEAD~1 HEAD, sm5-4 shots 1, 13, 14, sm5-6):
1. station_extras.py:+292 builds poster(cell, 3.0, 1.5, 0.05), a 6 x 3 m face in a 50 mm frame; fixtures.py:+40-42
   bounds of +-3.05 x +-1.55 match it; WIDE_Y 2.4 (+55) puts it at 0.85 to 3.95 with the frame, under the 4.1 vault.
   Clearances, worked from fixtures.py:+89-90 and subway.json: north 28 and 38 clear the boards at 22 and 44 by 1.49
   and 1.49 m and each other by 3.9 m; south -35, -17, 4 and 23 clear the boards at -44, -26, -8 and 14 by at least
   1.41 m. test_sm5_qa.gd:+182-192 now asserts 6, y 2.4, board gap 3.05 + 1.46, poster gap 6.1.
1. Readability at 112 px/m: in sm5-6 the smallest line ("Bikes by the hour ...") is about 0.15 m tall, about 17
   texels; the titles are about 0.33 m, about 37 texels. From 4 to 8 m on a 1080p screen at a 75° FOV, a metre is
   about 235 to 117 screen px, so texels are shown at 1 to 2x. The titles stay crisp; the small line is soft at 4 m
   but still legible. Shots 13 and 14 match a 6 x 3 m poster when measured against the 2.9 m board (shot 14: about
   1.6x the board's width at its distance ratio).
6. station_signs.py:+260 the lamp's glow is now a neutral, greenish grey, off the team hues; the fixture hue gate
   passes. It still reads as a warm lamp beside the butter moon in sm5-6.
8. The record (+21, +51-54, +83-84), ASSETS (+85) and the changelog note (+7) say 6 x 3 m. The dark track bed is left
   to the platforms thread, under Known issues.
Advisory (non-blocking): sm5-4 shot 13's caption still says "3 x 1.5 m" (the contact sheet's label, not repo text).
   The sheet's frame and fixture art keep the same 38 triangles, so they cost nothing more.
Must-fix for the next attempt: none. Merge once tools/check.sh on 21ad054 ends green.
Owner should test in the game:
- From each platform at 4 to 8 m, read every line of the three trackside posters, the small bottom line included.
- Are 6 x 3 m posters the size you wanted, or too dominant next to the name boards?
- From the track bed, does a poster's top edge sit clear of the vault's curve, with no clipping?
- Do the two north and four south posters spread evenly between the boards, with no wall looking empty?
- Does the Lamplight Room's grey-green glow still read as a warm lamp?
- At a shallow angle along the platform, does the text shimmer or smear (mipmaps)?
