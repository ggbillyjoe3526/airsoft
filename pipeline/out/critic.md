Task: none · BP5 part 3 (models: held replicas merged, far versions, light_baking 0, figure maps shrunk)
Attempt: 3 of 4
Head: f331439 (QA and performance Pass on ba2cdb3; 23769d5 only adds cull_mode to the far fold and a typed class;
the coordinator's 47-file re-run on f331439 was still running at review: Accept stands only if it is green)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Failed checks, with evidence: none.
1: held_merge.gd `_finish` keys on cull_mode and `_far_paint` copies it, so the Cyber and Sniper open shells stay
two-sided; the magazine stays its own node at every distance; the finishes are kept per material and prewarmed; body ORM
is at 1024; pictures 1 and 3 match main. 4: test_an_open_shell_drawn_from_both_sides_stays_so_far_off would fail without
the cull key (2 surfaces, both sides kept), and the finish test compares cull_mode; 9/9 tests in test_bp5_models pass.
7: `Painted` replaces the untyped lists. 8: record, changelog, README row and PLAYTEST are current.
Must-fix for the next attempt: none.
Owner should test in the game (at most 6, one line each):
- Low, a teammate with the Cyber Pistol at 20-30 m, scoped, from all sides: no see-through panels.
- Low, a bot reloading at 20-30 m, scoped: one magazine, the well empty while it is out.
- High, sunny field, bot at 30-40 m scoped: metal parts keep their shine, no jump at the far line.
- Stand 1 m from a bot: belt, buckles and cap look as before.
- Rifle on the back and pistol in the holster sit where they did.
