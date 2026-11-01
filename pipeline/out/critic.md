Task: SR1 · See-through railings on The Street
Attempt: 1 of 4
Head: a5ac2c4 (checks passed on it)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept (QA Pass, performance Pass)
Evidence for the passes (brief, no task block): bars drawn from the same boxes a BB meets (railings.gd:115 parts, map_level.gd:+408 _railing_mesh); BBs use bb_ray in BBStep (bb_step.gd:+60) with exact bar/rail slab tests (railings.gd:140); sight passes (jolt_query.gd:+53 set_railing_bodies), cover uses sight_clear so a railing is never cover (bot_cover.gd:100,180), shot checks pass (bot_senses.gd:+38 shot_clear, bot_combat.gd:+147,+186,+236,+287); garden fences solid (test_sr1_railings.gd:281). Contracts 1 and 4 kept: Railings is RefCounted in game/sim, reached only through WorldQuery; BoxWorld and JoltQuery both answer. No per-tick allocation: first_bar/bb_ray use packed arrays, reused _bar_hit and static scratch; _index() allocates once, on the first query.
Failed checks, with evidence:
8. [judgment] game/config/railing_config.gd added but game/config/README.md has no row for it (the folder README rule for a file added).
Must-fix for the next attempt: none blocking. Before merge, add the railing_config.gd row to game/config/README.md (docs-only, same PR).
Advisory (not blocking):
- SoundPath (sound_path.gd:11,16,28) still casts `ray`, so a railing muffles footsteps and shots behind it like low cover (0.5 share) for bots' hearing and the player's occlusion; open bars shouldn't. Worth a follow-up row or ray_past_railings there.
- A few bot checks still treat the box as solid sight: _slice_towards_last_known (bot_combat.gd:97), the crossfire lane pick (bot_movement.gd:433), held angles (bot_angles.gd:48), pings.gd:223. Bots may "slice" toward a spot they can already see through a railing; the same precedent BQ1 left for glass.
- Performance's advisory stands: the Railings mesh casts shadows and spans the map (map_level.gd:+155), never frustum-culled; check Low.
Owner should test in the game:
- Look through the front-garden railings by day and night: bars read cleanly at range, no shimmer.
- Shoot at a bot behind a railing: most BBs get through, some ping off a bar or rail.
- Crouch behind a railing with a bot facing you: it sees you and shoots; it never hides behind one.
- Try to walk or throw a bomb through: both stopped.
- A Street match on Low: frame time with the railings in view (shadows on).
- Footsteps of a bot just behind a railing: do they sound muffled?
