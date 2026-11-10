# SL4 · Sunlit Concrete: menus, HUD and replicas

**Review:** 3 attempts · critic Accept 8/8 (Opus) · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | Opus 5.5 (build thread) | ✗ (test_lo3_qa) | 5/8 Retry | navy left in MinimapConfig, charcoal copied as literals, FEATURES and KNOWN_ISSUES stale |
| 2026-11-10 | 2 | Opus 5.5 (build thread) | – | 8/8 Retry | procedural: QA and performance re-run on the final head |
| 2026-11-10 | 3 | Opus 5.5 (build thread) | ✓ | 8/8 Accept | – |

## Decisions

- **One palette, in `GameTheme`** (concept B's "flatter, quieter panels: off-white and charcoal, with team colours as
  the only strong accents"): `BG` `#131311`, `PANEL` a warm charcoal at 0.82, off-white words (`TEXT` `#f2eee6`, the
  cards and hairlines in the same white), and the accent from teal `#25d0b8` to bone `#d8ccb2` with charcoal ink. Bone,
  not plain white, so the selection still reads apart from the words. `WARN`, `GOOD` and `BAD` a little quieter. The
  layout (UR1) is unchanged.
- **Every navy ink goes charcoal, derived from the palette** (critic): `BG` for the markers' and map's ink, the order
  wheel's scrim and the Armory's dots; a new `DEEP` `#0c0c0b` for the rail and the shades over a match or page; a new
  `PLATE` `#1f1e1b` for the notices, the report boxes (the crash screen's is the report panel's) and the Armory's picked
  card. The HUD preview's teal containers stay: they picture a map's containers.
- **Replicas: matte, at the look's paint saturation.** `ReplicaPaint` draws a paint at
  `look_paint_saturation` (read from project.godot's shader globals, the same value `LookConfig` pushes and the maps'
  `look_paint()` uses, in linear light) with roughness 0.64 (was 0.5) and the metal parts 0.48 (was 0.4). The bold
  schemes keep their hexes and two tones; the player's pick is unchanged. The Loadout's swatches show the paint as
  drawn. The Cyber Pistol keeps its own lit lines (its realistic grey is muted the same way).
- **Figures left as they are:** their kit textures are already realistic multicam, khaki and olive (about a quarter
  saturation), and the team plate carriers stay at full team colour (the readability rule).

## Known issues left

- Replicas have no edge scuffs yet; with the map models' scuffs, a polish pass (`docs/KNOWN_ISSUES.md` › Art).
