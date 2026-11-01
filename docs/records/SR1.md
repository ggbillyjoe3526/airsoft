# SR1 · See-through railings on The Street

**Review:** 1 attempt · critic pending · qa pending · performance pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-01 | 1 | Opus 5.5 (build thread) | ✓ | pending | – |

## What changed

- **Bars, not blocks.** Every block of `MapStyle.railing_kinds` (The Street's 42 metal railings, 206 m) is a
  `Railings` run: square bars 0.025 m at about 0.14 m centres, end to end, between a 0.04 m top rail and one 0.1 m up
  (`RailingConfig`, on `MapStyle.railing`). `MapLevel` draws each run's `parts` as one "Railings" mesh in the
  greybox's material (1,600 bars, about 19k triangles, one draw), so what you see is what stops a BB.
- **BBs.** `WorldQuery.bb_ray` (BBStep's ray) casts the level past the railings' boxes (`ray_past_railings`), then
  `Railings.first_bar` tests the bars and rails the path actually crosses, exactly (slab tests on the box, the rail
  bands and the one bar in line), filed in a 4 m grid. About three straight shots in four go through; a bar or rail
  hit is metal and can ricochet.
- **Sight and bots.** The railings' Jolt bodies are left out of the sight ray (as glass, BQ1) and a new
  "PastRailingsRay"; bots see through them, BotCover finds no cover behind one, and BotCombat's shot checks
  (`BotSenses.shot_clear`, the aim and friendly-fire rays) pass them. Movers, the level ray, thrown bombs, vaulting
  and the nav grid still meet the box.
- `BoxWorld.add_railing` answers the same headless. `GreyboxFaces.box_faces` shared with `faces_of`.

## Decisions

- **The 6 ft wooden garden fences stay solid (owner, decision card 2026-11-01; DECISIONS).**

## Defaults taken

- Bars are drawn from code, not a CC0 model: a model's bar spacing wouldn't match the gaps a BB passes, and the
  record of ST2 named that as the reason the railings stayed blocks.
- Bars 25 mm square at 140 mm: thick enough to read at range (thinner shimmered), about 75 % of straight shots
  through. A bot's shot check ignores the bars (they rarely stand on its line); its BBs still meet them.

## Checks

- `tests/unit/test_sr1_railings.gd`: gaps and bars, both rails, the gap under the bottom rail, the share through,
  a BB along a run, 3,000 random paths against the drawn boxes (AABB.intersects_segment), BoxWorld, BBStep in
  flight, a built level, a bot seeing and shooting through and finding no cover, and The Street (every railing bars,
  a wooden fence still solid).
- Pictures: `/mnt/project-files/playtest/street-sr1/` (before/after, eye height on High).

## Known issues left

- A baked map would draw its railings as solid blocks (no baked map has any; KNOWN_ISSUES).
