Task: ST1 · The Street (concept 3 as plain blocks in palette colours; no task block, judged against the brief)
Attempt: 1 of 4
Head: 915afe2 (= HEAD; QA Pass, performance Pass on it; tools/check.sh and the Street guards still running: verdict holds only if they go green)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✗
Score: 6/8 → Retry (near miss, judgment)
Evidence for passes, in brief: 1 data/maps.md:28 lists street public 5/5/6 at 180 s; test_street.gd:41 every block a palette
colour, :58 glass stops BBs and the open half doesn't, :80 railings/sills over vault and jump; guards wired at ci.yml:250-252.
2 no contract touched (layout values stay in data/maps/street.json and MapStyle). 3 no per-frame code; glass_materials()
(map_level.gd:165) runs once in _build_views. 4 test_street.gd:58 fails without the Glass mesh and :97 without Block.colour.
5 clear_kinds is MapStyle data, colour parse refuses non-integers (map_data.gd:337), static types throughout.
6 pastel palette, BB puffs not touched, glass solid to BBs, owner rulings for 82 m and 1.3 recorded (DECISIONS, FieldStandard).
Failed checks, with evidence:
7. [judgment] Two areas with swapped names: "Corner green" (tools/street/layout.py:162, left lane, z 40-48) and
   "Green corner" (layout.py:182, middle, z -6..2), ~45 m apart; the minimap names the area you stand in, so callouts
   collide (concept 3's notes only name "Green corner"); field_standard.gd:86 cites the other one. Also ci.yml:238 runs
   The Street's day matches under the job name "Night match guards".
8. [judgment] Docs the change affects not updated: docs/ASSETS.md:38 (map cards row) lacks assets/maps/street.jpg and
   :67-68 (map layouts) lacks tools/street/ (ST1); game/map/README.md:15 still says MapLevel draws every block as one mesh,
   one draw call (now a Glass mesh too) and its MapData/MapStyle rows omit Block.colour and clear_kinds. docs/wiki/Maps.md:131
   promises "free CC0 models replace them next", against docs/wiki/README.md:47 (describe what is in the game today).
   tests/unit/test_wa1_qa.gd.uid rides along from another task (harmless, out of scope).
Must-fix for the next attempt: rename "Corner green" to a distinct name (layout.py, rebuild street.json, fix
field_standard.gd:86); rename the CI job to cover day and night; add street.jpg and tools/street/ to ASSETS.md; update
game/map/README.md's map_data, map_level and MapStyle rows; reword Maps.md:131 to today's state ("plain coloured blocks")
or point at the Roadmap as line 10-11 does. Commit the Pass performance report (it is only staged; HEAD still holds the Fail).
Owner should test in the game:
- Shoot at a bot you can see through the House's glass: does the BB stopping on the pane feel fair, and do bots not seeing you through it matter?
- Waist-high 1 m railings can't be vaulted while 0.9 m low walls can: does that read, or feel like an invisible wall?
- Attack / Defend: can Alpha reach flag A (the House) in time with only a 1.3 head start?
- The ~80 m cross-lane diagonals over railings and cars: do they dominate rounds?
- The pastel terraces and cars against the team colours, by day and under the lamp pools at night.
- Glass at 0.35 opacity, day and night, from both sides; the Glass mesh against the sky.
