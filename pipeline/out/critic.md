Task: ST1 · The Street (concept 3 as plain blocks in palette colours; no task block, judged against the brief)
Attempt: 2 of 4
Head: 91825e4 (= HEAD; QA Pass, performance Pass on 915afe2, still valid: 915afe2..91825e4 changes only CI, docs, a test
reason string and street.json's areas list, which holds names only; tools/check.sh and the A/D guard still running, so the verdict holds only if they go green)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. data/maps.md:28 lists street as public 5/5/6 at 180 s. test_street.gd:41 checks every block is a palette colour, :58 that the
   glass stops BBs and the open half doesn't, :80 that railings and sills clear vault and jump height. The guards run as their
   own CI job (ci.yml:273-283), and Elimination at Normal passed locally (117 rounds, 16 seeds, 0 on time).
2. No contract touched: layout values stay in data/maps/street.json and MapStyle.
3. No per-frame code. glass_materials() (map_level.gd:165) runs once in _build_views.
4. test_street.gd:58 fails without the Glass mesh, and :97 fails without Block.colour.
5. clear_kinds is MapStyle data. The colour parse refuses non-integers (map_data.gd:337). Static types throughout.
6. Pastel palette, no gore, glass solid to BBs. The owner's 82 m and 1.3 rulings are recorded (DECISIONS, field_standard.gd:83-92).
7. Area names now distinct (layout.py:157-182: Lower green, The lawn, West/East gardens, Left/Right bays; the Cul-de-sac's
   two boxes adjoin). The Street's guards have their own "Street match guards" job; Woodland's night job is as it was.
8. ASSETS.md:38 and :67-69 list street.jpg and tools/street/. game/map/README.md covers Block.colour, the Glass mesh and
   clear_kinds. Maps.md:131 states today's state with a Roadmap link.
Notes (not failures): "Back garden" (the House's) beside "Back gardens" is close but names distinct places. The
test_wa1_qa.gd.uid file from another task rides along and is harmless.
Owner should test in the game:
- Shoot at a bot you can see through the House's glass: does the BB stopping on the pane feel fair, and does it matter that bots don't see you through it?
- Waist-high 1 m railings can't be vaulted while 0.9 m low walls can: does that read, or feel like an invisible wall?
- Attack / Defend: can Alpha reach flag A (the House) in time with only a 1.3 head start?
- The ~80 m cross-lane diagonals over railings and cars: do they dominate rounds?
- The pastel terraces and cars against the team colours, by day and under the lamp pools at night.
- Glass at 0.35 opacity, day and night, from both sides; the minimap's area names as you cross the Street.
