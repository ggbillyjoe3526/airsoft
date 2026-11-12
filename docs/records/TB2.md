# TB2 · Subway's running tunnels arched like the trains

**Review:** 2 attempts · critic pending · qa pending · performance pending

Owner's ask (2026-11-12): "Subway tunnel should be curved/arched to closely math the shape of the trains." A second
pull request after TB1 (#318), which vaulted the platform tunnels.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | ✓ | 6/8 Retry | the box car standing in the south running tunnel poked through the arch (its roof cut away, its sides through the lining); the arch unseen in the dark tunnel; an always-true test assert, a stale rib comment |
| 2026-11-12 | 2 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **The arch follows the car.** Each running tunnel (x 50 to 82, 3.6 m across) has straight sides to `RUN_SPRING`
  2.7 m over the track bed, 1.8 m over a car's floor where SM1's car starts to lean in, then a segmental arch to the old
  roof at 4.1 m (`layout.RUN_VAULTS`, rise 1.4 m): about 0.15 m clear of a car's shoulders (1.55 m from its middle at
  1.95 m over its floor) and 0.5 m over its crown. The platform tunnels keep TB1's vault (`VAULT_RISE` 2.5 m).
- **One vault code for both.** Each vault names its rise, its style (`track` for the platform tunnels, `tunnel` for the
  running ones), its finish (the running tunnels wear the tunnels' `lining`, not tiles) and an open mouth (`west`,
  where the running tunnel meets its platform tunnel: no end cap there; StationSurface draws the portal's corners in
  the wider tunnel's wall finish instead). TB1's trims (frieze, cables) stay on the `track` vaults only.
- **Colliders as TB1's.** `build_map.vault_boxes` stands at most `VAULT_PROUD` 8 cm in front of the arc. A running
  tunnel's straight sides are its rooms' walls, so the vault adds no side walls or lower caps there; the air under each
  arc (`vault_inner`) is cut out of the shells and of the other vault's boxes, except a train's own shell.
- **Below the springing nothing moved:** the rooms, cover, wagons, cross passage and climb ledges are the greybox's;
  only the room ceilings over 2.7 m became arch. The detrainment steps at the south cab (`cab_steps`) sit under the
  arch like the rest (when SM1 lands, its own steps replace them).
- **Tunnel lamps** hang at 2.45 m (`fixtures.LAMP_Y`), under the springing, so their fittings never cut the arch.
- **A standing car fits under the arch** (attempt 2). The south train stands half in its running tunnel (x 50 to 60),
  and the greybox car is a 3.5 m box in a 3.6 m tunnel: no arch clears its corners. Where a car stands under a
  running arch its shell is shaped to it (`build_map.under_arch`, `car_shoulders`): across the car in 0.1 m steps,
  each no higher than `CAR_CLEAR` 12 cm inside the arc (measured from its middle), its roof stepping down over the
  shoulders as SM1's rounded car does, and its air a roof's thickness under that. The arch's colliders now run
  unbroken over the car, and the vault tests no longer let a train off.
- **The cab steps under the arch** open onto the ways round them up to the arch (two rooms under one vault open to
  it, `shell`), as they did under the flat roof before.
- **Tunnel lamps light the arch** (attempt 2): the roof's strip lamps hang under the crown and shine straight down,
  and on Low and Medium the overhead light stands in for them from above, so nothing lit the arch's down-facing
  lining and the tunnels drew black above the wall. Each wall-mounted tunnel lamp (SM5's) now carries a short
  shadowless light at its glass (`StationFixturesConfig.lit_models`, 6.5 m at 1.5, the glass's warm white), on every
  preset: a dozen lights, in the running tunnels only.

## Known issues

- The car's stepped shoulders show on the greybox box car until SM1's train models draw over its shell.
- The tunnel lamps' lights are on every preset, Low and Medium too (where the roof's lamps are no real lights), so
  the arch reads there: a dozen shadowless lights, judged by the performance review, not measured on a modest PC.
- Pictures (concepts/metro/tb2/v3/) are Forward+ on High and Low; Ultra not rendered.
