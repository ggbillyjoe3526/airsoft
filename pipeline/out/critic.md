Task: SL4 · Sunlit Concrete: menus, HUD and replicas
Attempt: 3 of 4
Head: 3e9bf5e (gdlint, changelog, wiki, unit parts 3-6 passed; parts 1, 2, 7 and smoke still running)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept, provided unit parts 1, 2, 7 and the smoke test pass on 3e9bf5e (any failure makes it Retry, measured)
Evidence: attempt 2's must-fixes are met. QA (pipeline/out/qa-report.md) and performance (pipeline/out/performance.md)
both Pass and name 3e9bf5e. docs/KNOWN_ISSUES.md:16 now says "the replicas included (SL4 made their paint matte and
muted)". dafc0bf renames navy_box to dark_box at every caller and warms the last cool greys. ReplicaPaint.drawn() and
paint_saturation() (game/play/replica_paint.gd:+104,+113) run only when a cached material is built, never per frame.
Nits (non-blocking): the Rec.709 luma weights at replica_paint.gd:+107 could be one named const. Commit the two
reports with the records. Leave the untracked tools/_ui_pictures.gd(.uid) out of the commit, or delete it.
Owner should test: the list in docs/records/SL4.md and the Dev 3 checklist (the menus, HUD, minimap and replica paints
under Sunlit Concrete on a real display; check that bold schemes still read as two tones).
