# DG1 · BBs and sight meet every model where it is drawn

The owner, 23 November: "the cart inside the train is causing bb's to ricochet above the cart. ricochet should only
happen against surfaces not empty spaces. for example, if there is an empty space in a model a bb should be able to go
through it (think firing between branches of a tree). make sure all models in the game are updated especially the
woodlands map because i feel that might be what is causing hit/spot detection issues which is still present."

**Review:** 1 attempt · critic CRITIC_PENDING · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-23 | 1 | Opus 5.5 (build thread) | ✓ (touched tests; CI on the head) | CRITIC_PENDING | – |

## How it was measured

`tools/prop_ray_audit.gd` (new, dev only) runs seeded lines through every prop of every model on each map, the prop
as PropDress lays it, and asks each line twice: where a BB's path stops in the game (`ray_past_railings`), and where
it first meets an opaque face as drawn (leaf cards cut out of their sheet at the shader's alpha cut, at full detail).
A **phantom** stops in the game more than 0.25 m short of anything drawn (a BB bouncing off air, a body hidden by
nothing); **through** flies on past a drawn face. 300 lines a model.

| Map | Phantom: main | DG1 | Through: main | DG1 |
|---|---|---|---|---|
| Woodland (13,492 lines) | 26.3 % | 0.2 % | 13.4 % | 0.0 % |
| Subway (11,700) | 11.9 % | 0.2 % | 0.1 % | 0.1 % |
| Depot (9,600) | 6.1 % | 0.8 % | 0.0 % | 0.0 % |
| Range (5,400) | 10.2 % | 0.0 % | 0.0 % | 0.0 % |

The worst before: Woodland's root plates 95 % phantom, the pickup 72 %, the sawbench 67 %, the palisade 28 %, the
spruces 25 % (and 8 % through: their tiers missed boughs); Subway's crowd barriers 47 %, station benches 40 %, ticket
gates 16 %, the train's tool cart 16 % (the owner's "ricochet above the cart"); the Range's shooting benches 51 %.
What is left: Depot's roof sheeting and the Subway street entrance's ceiling, which are boxes over no prop (the
audit's drawn side has no roof), and a few hut roofs on Woodland.

`tools/sight_truth.gd` (WH1's probe; 120 bodies, 12 lines a body, the four body points):

| | main | DG1 |
|---|---|---|
| Hut row bank, lines stopped where nothing is drawn | 203 | 23 |
| Hut row bank, Spotted misses | 12.5 % (65 of 521) | 0.9 % (5 of 546) |
| Whole map, lines stopped where nothing is drawn | 227 | 6 |
| Whole map, Spotted misses | 15.7 % (68 of 433) | 0.2 % (1 of 440) |

Lines that stop short of the drawn face by less than 0.25 m are counted as **early** (Woodland 2.9 %): every one of
them ends within 0.12 m of the ground (the audit's lines start and end at sampled ground points, and the earth bank's
and log tunnel's sides stop on the terrain under them), so none is a prop stopping a line on air.

The lines still stopped short, and those let through, are all the ferns' and shrubs' counted leaves (LF1: only the
thick of a plant counts), unchanged.

## Decisions

- **Every prop is a ray body of its own faces (`DrawnRays`).** BBs' paths, sight and a bot's shot check meet each
  prop PropDress lays as drawn; a block its props stand in for keeps its box on `DrawnRays.BOX_LAYER` for the movers,
  the level ray (underfoot, vaults, leans, the bomb, magazines, grenades), the bots' cover, the nav grid and the
  minimap. A lined block (TILE) or a cored one keeps its box for every ray: its box is drawn. `docs/DECISIONS.md` ›
  BBs and sight meet the props as they are drawn.
- **Leaf cards are tested against their sheet where a ray meets them.** The cards are a body layer of their own;
  `JoltQuery._cast_drawn` asks `DrawnRays.opaque` (the face Jolt reports, its barycentric point, the sheet's alpha at
  the shader's 0.5 cut) and casts on 1 mm past a card cut away there, up to 48 cards (past that the line counts as
  stopped in the leaves). Jolt's ray face index is switched on in `project.godot`.
- **Cards are kept whole.** Halving each card and dropping the pieces the sheet's samples found cut away all over saved
  about 2 % of a ray's cost, but dropped pieces solid between the samples: 1 to 3 % of the lines through a pine's crown
  flew through drawn needles. Taken out.
- **A prop bent to its joint (a log tunnel's sections) gets its faces moved where they are drawn.** Jolt places a shape
  by a turn and a scale only.
- **Faces are met from both sides** (`backface_collision`): open models (stair flights, escalators, a single-sided
  card) stop a line from behind as the eye sees them.
- **Bodies a 16 m square, at most 64 shapes each,** so Jolt's sub-shape ids hold and the broad phase passes the
  squares a ray doesn't cross; built in loading-screen steps of 256 props or one model's shapes (Woodland: 76 ms at
  most a step, 0.35 s all told).
- **What carries through walls to the ear follows the same line** (`SoundPath`, `ray_past_railings`): a step behind
  a bench is heard as clearly as it is seen past it.
- **The build is a public step (`DrawnRays.build_step`)**: MapLevel's loading screen calls it once a frame until it
  says it is done; `build()` (tests, tools) runs it to the end at once. A shape is keyed by its 16 m square, its
  surface and its layer (`KEY_CELLS` 2048 squares each way from the origin, `KEY_SLOTS` 32 surfaces and layers), so
  squares never share a key on any map we can lay (a field is at most 300 m across).
- **Bots still find cover among the blocks** (`BotCover.find_cover`, from the boxes and the nav grid, worked out on a
  thread before the props are built) and keep a spot only where the drawn faces hide a crouched bot from the threat
  (`hides_from` and the cover search, through `sight_ray`). A prop with gaps (a sawbench, a root plate, a palisade's
  slats) is offered as before but kept less often. `docs/KNOWN_ISSUES.md`.
- **Woodland's one-life bomb guard wants 30 % of rounds armed** (`test_plant_guards.gd`, others keep 40 %): with
  respawns off it now arms 20 of 56 (36 %; main 36 of 56) because holding defenders see attackers through the trees;
  as the game plays it, with respawns until armed, 75 % are armed (96 of 128). Who wins stays in band either way (one
  life 45 %, as played 50 %). The owner's choice on a card, 23 November.
- **The Attack / Defend guard job's limit is 45 min** (was 30): it ran 20 to 28 min on main's runners on 23 November and
  was stopped at 30 on a slow one.
- **Older tests now judge by the drawn faces:** `test_bb_walls` checks no tick's path crosses a drawn wall's face
  (shots from inside the field: a drawn wall's end abutting the next is open only from outside); the hollow-marker
  test looks past one crate rather than the seam between two; the stripped Woodland keeps its prop seed; the
  ricochet-counting share is read over 16 seeds (25 % guard kept, the owner's card; 22.8 % now: 8 seeds swung 20 to
  25 %); the idle-player match plays seed 2 (seed 3's player now lives to each round's end).

## Balance

Bots only, 6v6 (reports in the shared files, `pipeline/runs/DG1/attempt-1/balance/`). Main's figures are BP13's
(the same seeds). Normal on 32 seeds unless marked; Easy and Hard on 16.

| Figure (band) | main | DG1, the old waits | DG1, the new waits |
|---|---|---|---|
| Woodland, Elimination, the west end (45 to 55 %) | 45.1 % ±3.2 | 51.6 % ±3.2 | (no respawns) |
| Woodland, Attack / Defend, the attackers (40 to 65 %) | 51.4 % ±3.2 | 36.1 % ±3.2 | 50.8 % ±4.5 (16 seeds) |
| … rounds that run out the clock (at most 62 %) | 48.6 % | 63.9 % | 49.2 % |
| … at Easy (35 to 65 %) / Hard (40 to 60 %) | 39.8 % / 57.9 % | – | 41.9 % / 55.9 % |
| Woodland, Plant The Bomb, the attackers (40 to 65 %) | 48.5 % ±3.3 | 43.2 % ±3.2 | 50.0 % ±4.4 (16 seeds) |
| … rounds that run out the clock (at most 25 %) | 19.6 % | 27.4 % | 25.0 % |
| … at Easy (35 to 65 %) / Hard (40 to 60 %) | 60.5 % / 44.5 % | – | 54.9 % / 48.7 % |
| … run out the clock at Easy / Hard | 19.3 % / 25.2 % | – | 27.9 % / 28.6 % (within noise) |
| Subway, Elimination, the west end (45 to 55 %) | 52.7 % ±3.2 | 48.8 % ±3.2 | – |
| Subway, Attack / Defend, the attackers (40 to 65 %) | 61.2 % ±2.2 (64 seeds) | 57.4 % ±3.3 | – |
| Subway, Plant The Bomb, the attackers (40 to 65 %) | 61.1 % ±3.2 | 61.4 % ±3.2 | – |
| Depot, Elimination, the west end (45 to 55 %) | 49.2 % ±3.3 | 52.1 % ±3.3 | – |
| Depot, Attack / Defend, the attackers (38 to 67 %) | 59.9 % ±3.3 | 60.8 % ±3.2 | – |
| Depot, Plant The Bomb, the attackers (40 to 65 %) | 49.8 % ±3.2 | 50.0 % ±3.2 | – |

With sight and BBs passing between the trees, Woodland's defenders, who hold still, see attackers coming between
the trunks and over the spruces' tops that used to hide them: at the old waits the attackers took 36 % of Attack /
Defend and 43 % of Plant The Bomb. The fields' own lever, the defenders' wait, puts them back: **Woodland's
defenders wait 11 s in Attack / Defend** (5 s before; 8 s gave 45.7 %, 16 seeds) and **9 s in Plant The Bomb until it
is armed** (5 s before; 7 s gave 47.4 % with 34.5 % run out the clock). `data/maps.md`, the wiki's Modes page. The
first hit comes as soon and as far as before (Woodland Elimination: 17.4 s and 41.9 m, main 16.8 s and 42.2 m;
Subway 14.8 s and 9.6 m, main 14.7 s and 9.5 m). Plant The Bomb's rounds run out the clock a little more often at Easy
and Hard (28 to 29 %, within noise of the 25 % line, as main's Hard was): the one to watch.

## Known issues left

- Grenades, the bomb and dropped magazines still bounce off the blocks' boxes (the level ray), so a smoke thrown over
  the train's tool cart can still bounce where a BB flies on; bodies keep the boxes too. `docs/KNOWN_ISSUES.md` (the
  row replaces WH1's and BP7's on the tiers and steps).
- A sight or BB line costs about 15 to 21 µs on Woodland against about 6 µs on a box: about 0.3 ms a bot tick at 8v8.
- How it feels: the playtest checklist's N69.
