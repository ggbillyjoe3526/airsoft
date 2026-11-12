Task: SM5 · Subway's lamps and extras
Attempt: 9 (past 4; review-cap ruling: keep fixing until the critic passes), William's ask for more and larger posters
Head: 931e139 (= HEAD). Full tools/check.sh started on 94294ee and NOT finished when judged: gdlint, changelog and wiki
   passed, the GUT run is still going. 94294ee..931e139 adds only the sheet's pixels, station_signs.py, docs, QA's
   test_sm5_qa.gd (QA ran it 13/13) and reports; no runtime script changed.
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept (merge only once tools/check.sh ends green; the verdict lapses if it fails)
Failed checks, with evidence: none.
Checked this attempt (git diff 1cfb98f 931e139, sm5-6-posters.jpg):
6. station_signs.py:+266 "THE LAMPLIGHT ROOM": no well-known real club, bar or brand uses it (I know of none; any
   same-named small venue is obscure, and generic "Lamplighter" pubs are a different name). No "Nightjar" is left in
   code, data or docs outside the history rows. The other names are invented or generic: Halden Tea (Halden is a
   Norwegian town, not a tea brand), Fizzbee (a software tool's name, not a drink), Copperhill (a small US town's name,
   used here as a fictional town, with Lido, Pier, Cycle Hire, Library, Airsoft Club, Depot Yard), Read Late, Chrono
   Night and Saturday Market (generic phrases). None is a well-known real brand.
1. poster_j in sm5-6: the lamp shade, bulb and three-step glow read clearly as a hanging lamp, with the crescent moon
   and the stars top right. The title fits in one line at 64 px (+266) and all four lines stay inside the poster.
   poster_e (+182): the rounded notch now reads as a nose cut-out under the goggles, not a trapezoid.
1. records/SM5.md:+19-20: attempt 8's row is filled in and attempt 9's added; the club's name is updated at +48.
Advisory (non-blocking, carried over): the wide posters print at 224 px/m against the small ones' 336; poster_wide_c's
   birds still read as gulls, which suits a pier.
Must-fix for the next attempt: none. Merge once tools/check.sh ends green with test_sm5_qa.gd included (re-run it on
   931e139 if the 94294ee run doesn't cover it).
Owner should test in the game:
- Stand on each platform and look across the track: do the 3 x 1.5 m posters read, and are they big enough?
- Walk the passages: do 13 designs feel varied, with no twin posters side by side?
- Read a small poster at 2 to 3 m: is the small text crisp, not smeared by mipmaps?
- Does the Lamplight Room poster read as a lamp and a jazz night at a glance?
- Check the edge warning at 0.7 m sits behind the yellow line, clear of "Mind the gap".
- From the track bed, do the trackside posters sit at a believable height under the vault?
