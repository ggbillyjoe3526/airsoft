Task: TB1 · Subway's platforms like the Tube
Attempt: 2 of 4
Head: 7306510 (checks passed on it)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✗ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 5/8 → Retry

Failed checks, with evidence:
1. [judgment] The branch no longer merges: SM5 (#315) landed on main; `git merge-tree HEAD origin/main` conflicts in
   game/map/station_dressing.gd, data/maps/subway.json and docs/PLAYTEST.md. Once merged, the frieze (3.88 to 4.08 m,
   2 cm off the trackside wall) and SM5's 6 x 3 m trackside posters (centred 2.4 m, tops 3.95 m, 2 cm off the same
   wall) share a plane for 7 cm along every wide poster's top: z-fighting.
4. [judgment] The attempt-1 blocking defect (the black wedge over the north car) is fixed by a zone in
   tools/subway/station_dress.py:76-80, but no test covers it: deleting the zone keeps all 5888 tests green.
8. [judgment] Docs promise what the game doesn't show: docs/PLAYTEST.md and docs/records/TB1.md call the ribs "pale"
   (tint c8cbcc), but every v5 render shows them charcoal; the record still says SM5 is "in progress as this merges".

Passed, briefly:
- 2: no contract touched.
- 3: vault, ribs, trims and words built once at load (StationSurface.mesh); no per-frame work.
- 5: typed throughout; look values live in StationLook.
- 6: v5 renders show white walls, a curved tiled vault, yellow only at the platform edges; the wedge is gone.
- 7: scripts 169 to 331 lines; no nodes added.

Must-fix for the next attempt:
- Rebase on origin/main (keep SM5's Fixture and this task's Trim, Words, TunnelVault; rebuild subway.json); keep the
  frieze and the wide posters off one plane; check SM5's hung signs and clocks against the vault rooms.
- Re-run tools/check.sh, QA and performance on the rebased head, with renders that include SM5's fixtures.
- Add a test: the trackside wall over each car takes wall_tile and the air over it is the track's.
- Make the ribs read pale, or change the record and PLAYTEST to match what is drawn.

Owner should test in the game:
- Shaded platform floor and track bed read navy blue in every render (on main too).
- Ribs show as dark rings on a grey vault: right for the Tube?
- The vault is still mid-grey against white walls (known issue row).
- The top edge of the wide trackside posters against the dark frieze: no flicker.
- The frieze reads blue rather than green-grey under the cool fill.
- F3 on Low along a platform: 60 FPS with 40 % more station triangles.

(Restored by the build thread from the critic's hand-back; the file first copied here was another task's report.)
