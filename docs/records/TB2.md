# TB2 · Subway's running tunnels arched like the trains

**Review:** 1 attempt · critic pending · qa pending · performance pending

Owner's ask (2026-11-12): "Subway tunnel should be curved/arched to closely math the shape of the trains." A second
pull request after TB1 (#318), which vaulted the platform tunnels.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | Opus 5.5 (build thread) | pending | pending | – |

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

## Known issues

- The running tunnels stay as dark as before (lining, lamps every few metres): the arch reads mostly by its rings.
