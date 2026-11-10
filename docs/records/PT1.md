# PT1 · Baked path-traced lamp light (Ultra step 5): no sun's bounce under a lit roof

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|

## Goal

Step 5 of the owner's Ultra graphics (2026-11-09, `docs/ROADMAP.md`): baked path-traced light, for every map, Ultra
only.

## What was tried

- A path tracer in the game's own bake tool (headless, no GPU): each roof lamp's real light (its SpotLight3D, the
  engine's distance and cone falloff, the look's light curve) with shadow rays, then three bounces of 64
  cosine-weighted rays a vertex off the level's blocks and the roof's ceiling, onto every vertex of the baked mesh;
  drawn as light added on the site surface (a third custom channel) while the lamps shine. Depot baked in 35 s and
  its tests passed.
- **It barely shows.** Depot's hall is mostly models (shelving, containers, crates, the roof's bays), which a bake of
  the blocks doesn't cover, and its dark slab floor sends little light back up: the bounce was 2 to 8 % of the lamps'
  direct light on the blocks, and the pictures (High and Ultra) changed by under 1 % of brightness, about 2 % even at
  30 times the strength. Ultra's scene bounce (SDFGI) already bounces the lamps' light off every model: with the
  lamps' share of it turned off, Ultra's views lost 5 to 19 % of their brightness. A light grid every model reads would
  be coarser than SDFGI's 10 cm cells. Only full lightmaps (Cycles onto a second UV set of every model) would beat it.
- The work is kept as a patch, `art/graphics/pt1/pt1-lamp-bake-wip.patch` in the project files, with its test picture.

## Rulings and defaults

- **Stopped there (owner, 2026-11-10, on the decision card: "Stop here, keep live bounce"):** Ultra's scene bounce
  stays the lamps' bounce, and the Ultra push ends after step 4. Full lightmaps stay in `docs/IDEAS.md`, not planned.
- Kept from it, a fix the bake would have brought: while a roof's lamps shine as real lights (High, Ultra), the baked
  light is drawn without the sun's bounce (`MapLevel.set_baked_light(on, lamps)`), as no sun gets under the roof
  (UG2). The floor near Depot's open sides no longer reads warmer than its lamps make it (the KNOWN_ISSUES row).

## Checks

- QA attempt 1 failed it: the doors, poles and props kept the sun's bounce when only Lamp light changed, since
  PlaySession relit them only when Baked light switched. Now MapLevel counts its light's rebuilds
  (`baked_light_builds`) and PlaySession relights on each one; QA's test
  (`test_doors_and_props_follow_the_light_when_only_the_lamps_toggle`) passes.

- gdlint clean; `test_baked_light` (15, three new: the sun's bounce goes under shining lamps and comes back with them
  off, and a field with no roof lamps keeps it) and `test_graphics_apply` (15) pass; CI runs the full gate.
