Task: BU1 · Bots shoot it out in a bush at point blank (no task block; judged against the brief)
Attempt: 1 of 4
Head: e04e3dd (checks passed on e7a3add; e04e3dd adds docs only, game/ and tests/ identical)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. game/ai/bot_combat.gd:+368-378: flat distance within close_awareness switches to leaf depth to body_radius short of the aim point against leaf_stop_depth; far branch unchanged (+371-372). Seed 14 replay held_up 16 → 0 (brief, measured).
2. leaves_in_line signature and callers (bot_combat.gd:190, 292, 345) unchanged; no Contracts entry touched; no new tuning value (data-not-literals kept).
3. Close branch: Vector3/float locals only, one Foliage.depth() call as before, early-out for foliage-free maps kept first. No Array, Dictionary, lambda or string.
4. test_bu1_point_blank_bush.gd:+42: two capsules apart in a 3 m bush is ~0.64 m of leaves > 0.25, so the old rule returns true and assert_false fails; the sim test (+97) would time out with no hit on the old rule (both held, as in the bug).
5. Rule in the static sim-side BotCombat; limits read from cfg/tuning (close_awareness, body_radius, leaf_stop_depth); all locals typed by inference; no globals.
6. Fair and airsoft: within 2.5 m a bush already hides no one, and the player can always fire through leaves, so a bot that also fires at point blank makes a symmetric close-quarters shoot-out instead of two bots shoving. It still never wastes BBs into leaves that stop every BB (1.5 m deep still holds, +44). A player hiding in a bush next to a bot was already noticed; now it costs him, as a point-blank hit would on a real field. Right call.
7. Small hunk, comments updated in place, .uid files committed for both test files.
8. Changelog note, wiki line (config-driven number), PLAYTEST check, ai README, record. KNOWN_ISSUES row removal and the Dev 3 checklist line are due at ship once #335 merges (not on main yet): the thread must not forget them.
Advisory (non-blocking, not failures):
- game/ai/README.md:+29: the edited line runs past the doc wrap width ("(BU1). Shot at, ... At night"); rewrap.
- A BB through ~0.5 m of leaves comes out deflected and slow; QA's 0.5/0.65 m shoot-outs hit, but at 0.55-0.6 m of leaf a bot may spend several BBs for a hit. Watch it, don't tune now.
- Teammate standing in the same bush beside the target: leaf scatter is not added to the friendly-fire stray (record decision). Untested; low risk at < 0.6 m exit.
Must-fix for the next attempt: none.
Owner should test in the game:
- Woodland night, Normal, Elimination seed 14: no held-up stall, the bush fight resolves in seconds.
- Crouch deep in a big bush, let a bot walk in: it fires once pressed close (~0.5 m of leaf), not from 1.5 m deep in.
- From 3 m or more through a bush, a Normal bot still holds fire and goes round.
- Two foes meeting inside one bush: no one stands shoving into anyone.
- Point-blank BBs through leaves read right (rustle, leaf fall, hit lands) and don't feel like bots seeing through bushes.
- A bot with a teammate beside its target in a bush never hits the teammate.
