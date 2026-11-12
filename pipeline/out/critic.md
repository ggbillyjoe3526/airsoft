Task: SM5 · Subway's lamps and extras
Attempt: 8 (past 4; review-cap ruling: keep fixing until the critic passes), William's ask for more and larger posters
Head: 1cfb98f (= HEAD; QA ran test_sm5_qa 13/13 on 94294ee, 1cfb98f adds only reports and those tests; full
   tools/check.sh still running when judged: gdlint, changelog and wiki passed, the GUT run not finished)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✗ | 7 ✓ | 8 ✓
Score: 7/8 → Retry (near miss, judgment)
Failed checks, with evidence:
6. [judgment] tools/blender/maps/station_signs.py:+273 `line(d, h * 0.64, "THE NIGHTJAR", ...)` with "Live jazz every
   Friday" (+274): Nightjar is a real, well-known London live-jazz bar, so poster_j advertises a real venue under its
   own name and offer. That breaks the brief's rule (every name invented) and CLAUDE.md §4 (no real brand names).
   The other names look invented: Halden Tea, Fizzbee, Copperhill (Pier, Cycle Hire, Library, Depot Yard, Airsoft Club).
Passed, from images and diff (sm5-6, sm5-4 shots 1, 2, 13, 14):
1. Thirteen 2:3 posters (336 x 504 cells) and three 2:1 wide ones (672 x 336), station_cells.py:+9-21. Checked the cell
   rects: none overlap, and all sit inside 2048 x 2048. Every line of text sits inside its poster and reads in sm5-6
   (line() shrinks text to fit, +70-77). The wide posters in fixtures.py:+89-94 sit at y 2.3 between the name boards,
   no overlap (22/44 vs 26-40; -44/-26/-8/14 vs -36.5..24.5). No two neighbours share a design (QA test). The edge
   warnings are at 0.7 m, fixtures.py:+50, behind PT1's line.
6. Otherwise fits: the palette has no blue or orange (TEAL 2A9C90, VIOLET, CRIMSON, BUTTER). The topics are airsoft
   culture (goggles on, chrono night, new players, Skirmish Sundays) and gentle local adverts, with no weapons.
3/5. No runtime script changed except a config list and a picture tool; performance Pass (4.5 MB sheet, about 12 more draws).
Advisory (non-blocking): poster_e's nose wedge reads as a yellow trapezoid under the goggles rather than a cut-out; the
   wide posters print at 224 px/m against the small ones' 336, fine at track distance; poster_j's birds read as gulls.
Must-fix for the next attempt: rename "The Nightjar" on poster_j (station_signs.py:+273, the record's Decisions line,
   the module docstring is fine) to an invented club name that no real jazz venue uses, e.g. "The Lamplight Room";
   rebuild signs.png. Then merge once tools/check.sh ends green on that head.
Owner should test in the game:
- Stand on each platform and look across the track: do the 3 x 1.5 m posters read, and are they big enough?
- Walk the passages: do 13 designs feel varied, with no twin posters side by side?
- Read a small poster at 2 to 3 m: is the small text crisp, not smeared by mipmaps?
- Check the edge warning at 0.7 m sits behind the yellow line, clear of "Mind the gap".
- From the track bed, do the trackside posters sit at a believable height under the vault?
