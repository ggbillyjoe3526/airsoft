# DW1 · Depot's worn lamps: some dim, a few flickering, a couple dead

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | see Checks | Retry 6/8 | dim lenses read as working ones; dead lamps in edge rows beside dim ones; flicker barely shows on the floor |
| 2026-11-10 | 2 | thread | see Checks | Accept 8/8 | – |

## Goal

The owner (2026-11-10 04:10): "Can you add some variations to the lighting? I mean maybe some lamps aren't as bright
or they flicker or one that doesn't work", and (04:10) "This is just specific to depot map". After UG2 (no sun
indoors) the hall is lit by its lamps alone, so worn lamps vary its light.

## Approach

- **The map names them** (`roof.lamps[].state`: "dim", "flicker" or "dead"; none is working): `MapData` reads
  `roof_lamp_states` (an unknown state is a working lamp, with a warning). Depot's builder
  (`tools/depot/build_map.py` › `wear_lamps`) picks 12 dim, 3 flickering and 2 dead with a fixed seed, the
  flickering and dead ones at least 15 m apart; a dead lamp only where all four neighbours hang (never an edge row)
  and all four work, so its patch is filled and no corner goes dark (critic, attempt 1). No other map names any.
- **The lenses** (`RoofView`): the glow is a small unshaded shader reading each lamp's tint from the MultiMesh's
  custom data (`lens_tint`): working and flickering in full, dim at `RoofConfig.lamp_dim_glow` (0.12: a lens glows so
  brightly that half still reads full white; critic, attempt 1) in the amber `lamp_dim_colour`, dead at `lamp_dead_glow` (0). On every preset.
- **The lights** (`RoofLamps`, High and Ultra): a dead lamp has none, a dim one shines at the same share and colour,
  a flickering one is out of the baked bounce light (BAKE_DYNAMIC) as its strength steps.
- **The flicker** (`RoofView.flicker_level`, pure): mostly full; every `lamp_flicker_every` (3.5 s), in each lamp's
  own phase, all but `lamp_flicker_quiet` (30 %) of the cycles a burst of up to `lamp_flicker_burst` (1 s) stepping
  every `lamp_flicker_step` (0.09 s) to nearly off (`lamp_flicker_low` 0.05) at `lamp_flicker_off` (60 %) odds, long
  and dark enough to show on the floor under it (critic, attempt 1). `_process` runs only on a roof with flickering lamps
  and sets a lens and light only when its step changes.

## Defaults taken

- Counts 12 / 3 / 2 of 93 lamps: enough to notice, few enough that the hall still reads evenly lit; a dead lamp's
  patch is filled by its wide-coned neighbours (UG2).
- Dim lamps amber (an older lamp), their light at 45 %.
- The flicker is a stutter, not a strobe: off at most 1 s in a burst, then full for seconds. A play check asks
  whether it distracts.

## Checks

- gdlint clean; `test_worn_lamps` 8/8 (Depot's states and only Depot's, a dead lamp among four working neighbours, an unknown state, a dead lamp with no light
  and a dark lens, a dim one's light and lens, a flickering one dynamic and following its steps, the flicker mostly
  on and the same every run, no processing without worn lamps); `test_lamp_lights` (one light a lamp but the dead),
  `test_lamp_lights_qa`, `test_ug2_qa`, `test_depot_hall`, QA's `test_dw1_qa` (7) and `test_dw1_qa2` (5, the flicker's levels and odds and each lens tint) pass.
- Pictures: `/mnt/project-files/art/graphics/lv1/`.

## Known issues left

- The flicker runs on wall-clock time, so it keeps stepping behind the pause menu (critic, attempt 2: left, a play check asks). At its off step a flickering lens glows about as much as a dim one.

- The lens shader's MultiMesh-with-custom-data variant is prewarmed on a plain quad (`shader_prewarm.gd`), as the
  roof's other MultiMesh materials are; Godot's ubershader covers the first real draw (performance review: check for
  a first-flicker hitch).
- Frame cost: three flickering lights change strength a few times a second (their shadows are redrawn anyway), out of
  Ultra's baked bounce light so SDFGI updates them while they change; no GPU in the cloud. If Ultra spikes during a
  burst, keep them baked and only fade their strength (performance). The owner's check is in the playtest list.
