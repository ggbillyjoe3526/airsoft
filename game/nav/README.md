# game/nav

Where bots and walk-offs can walk: the browser game's layered nav grid (`legacy/browser/src/nav/`), as plain data
built once per map from `MapData.blocks` and its sloping ground, `MapData.terrain` (no `Node`, no physics:
docs/ARCHITECTURE.md › Contracts 1).

| File | What |
|---|---|
| `nav_grid.gd` | `NavGrid`: a 0.2 m grid holding a node per floor of each cell in flat packed arrays, its queries (`node_at`, `floor_at`, `is_walkable_at`, `nearest_walkable`, `clear_line`, `drop_on_line`, `random_walkable_near`) and `find_route` |
| `nav_grid_builder.gd` | `NavGridBuilder`: each cell's floors (the terrain's ground at its centre, then each floor or ramp top), blocks and drops stamped with the clearance, the outer edge; each node's eight steps, the open-ground distances a line skips over, and the route search's points and links |
| `nav_route.gd` | `NavRoute`: string-pulls the search's node path into straight legs probed a body's radius from corners (the browser's pullRoute) |

- **Sloping ground** (WL1, the browser's M33c). A cell's ground is `TerrainGrid.height_at` its centre, with nothing
  under it; the grid's bounds take in the terrain's. A 1:2 slope rises 0.14 m over a diagonal step of a 0.2 m cell,
  under `max_step`'s 0.15 m, so every slope a ramp may have is walked. Steeper ground (WR1) links diagonally when both
  straight steps round the corner do and the diagonal climbs at most `max_step` x sqrt 2 (`_sloped_diagonal`), so a
  smooth bank up to 0.75 is walked on any heading; steeper, or a kerb's corner, is a drop.
- **Layers.** A floor over a floor is a second node of the same cells; every query takes a height and answers for the
  floor at it. Neighbouring nodes connect when their floors are at most `BodyConfig.max_step` apart, with no
  squeezing diagonally past a blocked node; drops keep the clearance on both sides, as walls do.
- **Search.** Godot's `AStar3D` over the walkable nodes, weighted (`NavConfig.search_greed`): GDScript is far too slow
  for the browser's hand-written A*. The browser's distance fields aren't needed. Its budget a tick (NAV.searchBudget,
  8,000 expansions) is `NavConfig.search_budget`, counted in searches since AStar3D runs one whole: one a tick, a
  walk-off due first (`Elimination.plan_walk_off_routes`), then the bots round-robin (`BotRoutes.plan`). `searches`
  counts them (WL2: at 6v6 on Woodland 2 to 3 a second, never a second in one tick).
- **Regions** (WL1). The build labels each walkable node with the lowest node it is linked to on foot, either way
  (`NavGrid.region`, a union-find over the links); `NavVaults.link` joins the regions a vault link crosses
  (`vault_region`). `find_route` refuses a goal in another region at once, before the search: a search that fails
  explores the whole grid (182–202 ms on Woodland, its hut and cabin roofs walkable but out of reach). A region joined
  only by a one-way step still gets the full search. Bots' hunt spots skip other regions (`RoundPlanner.hunt_point`).
- **Measured** on Depot headless, 2026-10-18, 4-core container: build 205–240 ms; 42,075 nodes, 27,363 walkable
  (the browser's 27,380: the map's numbers are single precision here); 100 random cross-map `find_route` calls mean
  1.2–1.5 ms, max 6.4 ms (the search about 0.7 ms of it), 100 random pairs anywhere mean 0.7 ms.
- **Woodland beside Depot** (WL1, 2026-10-24, the same container, `docs/records/WL1.md`): build 1.9–2.1 s against
  Depot's 223–247 ms (the links and regions 1.6 s of it; the regions about 0.2 s on Woodland, within the noise on
  Depot); 242,591 nodes, 220,146 walkable (Depot 42,075 and 27,593); vault links 16 in 0.64–0.71 s (Depot 10 in 0.10 s);
  100 seeded routes from the west quarter to the east quarter mean 1.8–4.0 ms, max 3.8–6.3 ms where one exists (Depot
  1.1–1.4 ms, max 2.9–4.4 ms). A goal on a roof is refused in about 0.06 ms (182–202 ms before the regions).
- **Built off the main thread** (WL2). Behind the loading screen `PlaySession` builds the grid on a `WorkerThreadPool`
  task (it is pure data) and waits for it frame by frame, so the screen keeps drawing: Woodland's longest frame went
  from 2.2–2.4 s to 0.9–1.1 s, the vault links' 0.7 s of Jolt rays (which stay on the main thread) the most of it.
- **Memory** (WL2, `OS.get_static_memory_usage` round a build): Woodland 167 MB, 155 MB of it `AStar3D` (737 bytes a
  walkable node: each point's neighbour maps and the link set); Depot 21 MB. A 0.4 m cell wherever a node's cell is
  open two cells round (88 % of Woodland's walkable nodes) would save about 100 MB but changes the search graph, so
  the routes bots walk: left (KNOWN_ISSUES).
- **Vault links** (`nav_vaults.gd`, browser M102): where `Vault.plan` vaults a body from a standstill on a node, along
  the grid's four axes, a one-way search point between that node and the first walkable one past the obstacle, priced
  at its length plus `BotConfig.vault_price` (3 m). A bot's route may take one (`find_route(..., vaults = true)`); a
  walk-off never does. Depot has 10, all over the hall wall, found in about 120 ms once per grid.

Tuning: `NavConfig` (`game/config/nav_config.gd`, `SimTuning.nav`); the body's radius, height and step from
`BodyConfig`. Tests: `tests/unit/test_nav_grid.gd` (the browser's grid tests, a two-storey map, Depot's dock, spawns
and dead zones), `tests/unit/test_nav_walk_off.gd` (a walk-off round a wall through `Simulation`),
`tests/unit/test_terrain.gd` (the browser's sloping-ground grid tests: floors from the ground, blocks on a slope, a
floor over the ground, routes up a 1:2 slope, none up a cliff, a platform out of reach its own region),
`tests/unit/test_bot_vaults.gd` (a wall across the field: two regions on foot, one by vault),
`tests/unit/test_woodland_layout.gd` (Woodland's camp-to-flag walks, a body walking every lane on the bots' routes,
hunt spots over the whole field and never on a roof).
