# SL4 · Sunlit Concrete: menus, HUD and replicas

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | – | – | – |

## Decisions

- **One palette, in `GameTheme`** (concept B's "flatter, quieter panels: off-white and charcoal, with team colours as
  the only strong accents"): `BG` `#131311`, `PANEL` a warm charcoal at 0.82, off-white words (`TEXT` `#f2eee6`, the
  cards and hairlines in the same white), and the accent from teal `#25d0b8` to bone `#d8ccb2` with charcoal ink. Bone,
  not plain white, so the selection still reads apart from the words. `WARN`, `GOOD` and `BAD` a little quieter. The
  layout (UR1) is unchanged.
- **Every navy ink in `game/ui/` goes charcoal** (rail, pause shade, report box, crash report, markers' ink, order
  wheel scrim, armory dots and picked card, graphics notice, the replica picture's glow), at about the same brightness.
  The HUD preview's teal containers stay: they picture a map's containers.
- **Replicas: matte, at the look's paint saturation.** `ReplicaPaint` draws a paint at
  `look_paint_saturation` (read from project.godot's shader globals, the same value `LookConfig` pushes and the maps'
  `look_paint()` uses, in linear light) with roughness 0.64 (was 0.5) and the metal parts 0.48 (was 0.4). The bold
  schemes keep their hexes and two tones; the player's pick is unchanged. The Loadout's swatches show the paint as
  drawn. The Cyber Pistol keeps its own lit lines (its realistic grey is muted the same way).
- **Figures left as they are:** their kit textures are already realistic multicam, khaki and olive (about a quarter
  saturation), and the team plate carriers stay at full team colour (the readability rule).

## Known issues left

- Replicas have no edge scuffs yet; with the map models' scuffs, a polish pass (`docs/KNOWN_ISSUES.md` › Art).
