# PB3 · The bomb with no animations

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-13 | 1 | Opus 5.5 (build thread) | pending | pending | – |

## Decisions

- **No animations (owner ruling, `docs/DECISIONS.md` › No animations on Plant The Bomb's bomb).** The first build
  (procedural hands on the bomb, the view bowing over it) was turned down and never merged.
- **The replica is put away for planting and defusing alike**, as for a bomb's throw (`Armament.put_down`), and drawn
  again at its own draw time on letting go (`PlantConfig.redraw_scale` 1.0); one already away stays away, and one hit
  while working is never drawn. This replaces PB1's 0.4 s `hands_back` lockout.
- **The player is not made to crouch** while working: he asked for no animation, and a forced crouch moves the view.
  Bots still crouch (`BotPlant`), as he asked.
- **The bomb is set 0.55 m ahead of the planter's feet** (`set_ahead`), short of a wall (`set_clear` 0.16 m, a ray
  at `set_ray_height` 6 cm), drawn in onto the site's ring if it would lie past it, facing the planter. It lies on the floor found by a ray down there
  (`set_drop` 0.3 m each way), so on Woodland's slopes it neither floats nor sinks;
  measured at the spot after the ring's pull, and with no floor there (a ledge ahead) it goes at the feet instead. On main it
  stood under the planter's feet, out of sight in first person.
- **The rail's bomb row** shows while you carry it, lit while you set it, keyed with Use (G). Your replica's row is
  unlit while it is away, as when holstered.
- **While your hands are on it the replica panel shows no HOLSTERED** (as for a throw: the rail's lit bomb row says
  what is in hand), and the quiet "You have the bomb" line hides while the PLANTING gauge runs.
- **BOMB ARMED** is the armed gauge's word for everyone, whichever team armed it; the gauge's word column grew from
  72 to 96 px to fit it, with an 8 px gap before the track (`HudStyle.GAUGE_LABEL_GAP`). The defuse still reads DEFUSING.
- **PB2's wire cutters** still lie open beside the bomb while it is defused: nothing in his ruling touched them.

## Known issues left

- None.
