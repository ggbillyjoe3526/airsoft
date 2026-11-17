# RS1 · Respawns, so a round runs its clock

**Review:** 2 attempts · critic PENDING · qa Pass · performance Pass

The owner's ask (playtest item 28, 2026-11-17): "matches should let players/bots respawn. i feel matches are over too
quickly because players get knocked out too fast. the player or bot can respawn after so many seconds. the idea is
that matches will last long. ... the player can choose to respawn at the starting area or at another area. show me
options for spawn points on each map." Pictures of each field's options went to him on 17 November
(`maps-redesign/respawn-rs1/` in the shared files); his rulings since: a shut spawn is only greyed out, and nothing on
the panel moves when it is.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-17 | 1 | Opus 5.5 (build thread) | ✓ (gdlint, wiki, changelog, touched tests; the rest in CI) | 6/8 Retry | No cue on coming back; Plant The Bomb unmeasured; no changelog note or README rows |
| 2026-11-17 | 2 | Opus 5.5 (build thread) | ✓ (as above) | PENDING | – |

## What the bots showed

Bot matches, 6v6, Normal, seeds 1 to 6 a field (the owner's rule: small balance runs in the cloud). With plain 10 s
respawns for both sides the attackers took 75 to 88 % of Attack / Defend rounds: nobody can be wiped out, so the
defenders win only by the clock, and two defending bots on the rope against every attacker coming back lost it.
Respawn delays alone barely moved Woodland (75 % at 10/10, 76 % at defenders 3 s, attackers 15 s).

| Field | Attack / Defend: attackers | Plant The Bomb: attackers | Median A/D round |
|---|---|---|---|
| Depot (defenders 15 s) | 47.4 % ±8.1 | 55.6 % ±7.4 (5 s) | 150 s (the clock) |
| Woodland (defenders 5 s) | 48.9 % ±7.3 | 65.9 % ±7.1 (5 s) | 180 s (the clock) |
| Subway (defenders 7 s) | 53.5 % ±7.6 | 57.4 % ±7.2 (at 7 s; it plays 5 s) | 150 s (the clock) |

Plant The Bomb at a 10 s defenders' wait: Depot 62.8 %, Woodland 71.1 %.

## Decisions

- **On in Attack / Defend, on in Plant The Bomb until the bomb is armed, off in Elimination** (one life is the mode);
  Custom's Respawns row: by mode, On, Off. `docs/DECISIONS.md` › Respawns.
- **The wait starts at the hit;** the walk-off plays as ever and the character comes back where it picked.
- **Forward spawns for both sides,** two an end on every field, shut with an enemy in play within 15 m. Attackers only
  was the first default; the defenders needed them to answer a raise.
- **An untended flag slips down with respawns** (15 s top to bottom), so a raise is finished, not built up a hit at a
  time, and **up to six defending bots retake** the pole in play (the other pole keeps its two first).
- **The defenders' wait is set per field in Attack / Defend** (`data/maps.md` Defender respawn: Depot 15, Woodland 5,
  Subway 7) and is 5 s in Plant The Bomb; the attackers wait 10 s.
- **Coming back reads:** the screen comes up out of dark with "Back in" and the shot timer's GO beep; anyone else's
  return is heard as a magazine stowed where they stand.
- **The balance report's clock band** with respawns: Attack / Defend's at most 62 % (the defenders' share the
  attackers' band leaves), Plant The Bomb's at most 25 %. The match guards play one life a round as measured; the
  respawn guards play the game's respawns on every field.

## Known issues left

- Woodland's Plant The Bomb attackers 65.9 % ±7.1, just over the band and within noise (a `docs/KNOWN_ISSUES.md` row): re-measure on more seeds
  before acting (its fuse or the defenders' wait are the levers).
