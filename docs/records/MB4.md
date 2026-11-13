# MB4 · Woodland's Brow hazel, back in its place

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

MB2's first push failed a night guard: two opposing bots stood inside one hazel on the Ridge's brow, 0.7 m off the
north lane, each with no shot through the leaves, each walking into the other. MB2 moved that hazel 2.3 m north to
get its checks green and left the bots' rule as a known issue. MB3 then measured what the move cost: the hazel was
the west's screen across the gap in the row behind it, and without it the west end took 41 % ±3 of Elimination's
rounds (47.5 % ±3 before; band 45 to 55 %). BU1 (#341) has since fixed the rule itself: two bots in one bush shoot
it out. So the hazel goes back.

## Acceptance criteria

1. The Brow hazel stands at (-16.3, -40.5) again, and the built map is the layout MB2's reviews read.
2. Bots, 6v6, Normal, Woodland's Elimination: the west end inside 45 to 55 %, on the 32 seeds MB2 and MB3 measured.
3. Woodland's Attack / Defend at its 9 s raise: the attackers inside 40 to 65 %, the same seeds.
4. No bot is held up there: the night seed that failed MB2's guard plays clean, and the guards pass.
5. A test holds the hazel across the gap it screens.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | build thread | ✓ | 8/8 Accept | – |

## What changed

- `tools/woodland/layout.py`: the middle hazel of the brow's front row is at z -40.5 again (MB2 had it at -38.2).
  `data/maps/woodland.json` is rebuilt, and is byte for byte the file MB2's QA, performance agent and critic read
  (commit 85e3f52, before the move).
- `tests/unit/test_mb4_brow.gd`: one bush stands at the hazel's place; from nine points east of the brow, at
  standing eye height, no line to the gap in the back row runs through less leaf than stops a BB or meets nothing
  solid (27 lines; on MB2's moved layout 2 of the 3 tests fail); the north lane is still walked end to end past it.

No new model, no new sound, no code under `game/`.

## Measured

Seeded 6v6 bot matches at Normal on Woodland (`tools/map_heat.gd`), seeds 1 to 32.

| Layout | Bots | Elimination, west end | Attack / Defend at 9 s, attackers |
|---|---|---|---|
| Hazel in place (MB2 as reviewed) | before BU1 | 47.5 % ±3.2 (114 of 240) | 58.6 % ±3.2 (136 of 232) |
| Hazel moved 2.3 m north (MB2 as merged, MB3) | before BU1 | 41.1 % ±3.2 (95 of 231) | 60.2 % ±3.2 (139 of 231) |
| Young spruce in the hazel's place (tried, not built) | before BU1 | 50.8 % ±3.3 (120 of 236) | 57.5 % ±3.1 (142 of 247) |
| **Hazel in place (built)** | **with BU1** | **47.6 % ±3.2 (117 of 246)** | **58.6 % ±3.2 (136 of 232)** |

- **The move is the likely cause, and undoing it is enough.** Three layouts that screen the gap read 47.5, 50.8
  and 47.6 %; the one that leaves it open reads 41.1 %, and 42 % ±2 over seeds 1 to 56 (177 of 418).
- **Attack / Defend at 9 s** plays the same 232 rounds with BU1 as the same layout did before it (136 to the
  attackers, 127 of them by a flag): the point-blank case never arose in these matches. With MB3's tally, 69 of the
  flags went up at flag A and 58 at flag B. Elimination's rounds differ a little (246 for 240).
- **Night seed 14,** the match that failed MB2's guard with 16 bot seconds held up (10 allowed), plays 9 rounds with
  none held up.

## Decisions

- **The hazel, not a clump of young spruce.** A solid clump in its place also brought the figure back (50.8 % ±3.3)
  and no bot could stand inside it, and it was the plan while the bots' rule stood. With BU1 merged the reason for
  it is gone, the hazel is what MB1 designed (a soft wall with a way through) and what the owner's pictures show,
  and the map file is the reviewed one again.
- **A bush on a lane where the squads first meet is not a fault any more.** It was one only through the bots' rule.

## Verified

- `tests/unit/test_mb4_brow.gd` (3 tests) and QA's `tests/unit/test_mb4_qa.gd` (1) pass, with `test_mb2_qa` (a
  seeded match in each mode on Woodland, no bot held up), `test_mb1_layouts`, `test_bushes` and
  `test_bu1_point_blank_bush` (63 tests in 7 files). gdlint and the wiki check pass. `tools/woodland/check.py`
  prints `TOTAL 0`.
- Criterion 1: `cmp` of the built map against `git show 85e3f52:data/maps/woodland.json` (identical); against
  `main` one foliage entry differs. Criteria 2 and 3: the table above. Criterion 4: night seed 14 replayed alone
  (9 rounds, none held up); the night guards run in CI. Criterion 5: with `main`'s map file in place the first two
  tests fail.
- QA: Pass. It recounted the four Elimination figures from the round files and rebuilt the map (the same bytes).
  Its test puts two opposing bots 0.5 m apart in the real hazel: each has a shot under BU1's rule. Advisory: at
  0.7 m apart through the hazel's middle the pair is still held for the leaves (BU1 opens at about 0.66 m); they
  keep walking and unlock 4 cm on, and seed 14 plays clean.
- Performance: Pass, with no bench: the map file is the one MB2's bench measured (Woodland 8v8, 4.63 ms a frame
  against 4.56), and nothing under `game/` changes.
- Critic: 8/8 Accept. It recounted the built layout's two figures (117 of 246; 136 of 232), found Attack / Defend's
  232 rounds the same round for round as before BU1, and compared the map file with 85e3f52's itself. Advisory:
  the lane test passes on either layout (it guards the lane, not the hazel), and if a night guard ever flags a bot
  held up at the brow, file it as a known issue rather than move the hazel again.
- **Not verified, for the owner's play:** whether the east's push over the Ridge's brow feels fair in Elimination.
  The play check is on the Dev 3 checklist.

## Known issues

- Deleted: the Maps row on Elimination leaning east (fixed here).
- Brought up to date: the Maps row on Woodland's Attack / Defend (the figure on this layout).
