Task: PB3 · head 1a9bf361 · Verdict: Pass
Run: no --perf bot run (tools/check.sh owns the machine and a second run collides); static diff review only · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the diff
Metrics: not measured this pass (node count, orphans, static memory, script time and draw calls unmeasured).
Regressions (> 10 % worse): none measured
Blocking findings: none
 - simulation.gd per-character loop (judgment): the two rays (Plant.room_ahead, Plant.floor_at) run only for the carrier holding Use before arming starts, into one reused RayHit (_set_hit). No Array, Dictionary or String is built per tick. Vector3 temporaries are stack values.
 - Plant.hands_on (judgment): bool checks per character per tick. put_down and bring_up run only on edges.
 - weapon_rail.gd:511 refresh (judgment): rows are rebuilt only when lit or carry changes. HudPlant.rail_carry is an enum compare per HUD frame with no allocation.
 - replica_pictures.gd:224 bomb_texture (judgment): built once (the _bomb_shot null guard), UPDATE_ONCE, same SubViewport rig and parent as the grenade shots. It is freed with the pictures node, so there is no new orphan path. weapon_rail.gd:98 calls it once in setup.
 - plant_view.gd refresh (judgment): only reads ps.set_at and ps.facing. No allocation.
Advisory:
 - replica_pictures.gd:239 (judgment): the bomb rig is never queue_freed on its own. Part shots are, so it is the same as the grenade shots. It is fine if ReplicaPictures is freed with the HUD, so confirm the orphan count in the next --perf run.
 - simulation.gd (judgment): floor_at runs every tick while Use is held with the bomb. A second cast is cheap, but it could be cached while the carrier is still.
 - The bomb picture is a new SubViewport with its own World3D. The first render can hitch, and the prewarm list has no entry for it (judgment, rendered hardware only). It draws once at HUD setup, not mid-round.
Fixes: none required.
Unexplained: none
