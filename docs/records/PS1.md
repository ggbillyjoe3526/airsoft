# PS1 · Bot personalities take jobs in Attack / Defend and Plant The Bomb

**Review:** 2 attempts · critic Accept ?/8 · qa Pass · performance Pass

The owner's ask (2026-11-18): bots already had four personalities, but in Attack / Defend and Plant The Bomb they
differed only in pace, cover, bursts and lanes (the Anchor's hold and its flag watch are Elimination's). "Do that and
make sure the game is balanced": give each a job there (who carries and plants the bomb, deep or forward defence,
forward spawns) and keep the attackers' share in its band.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-18 | 1 | Opus 5.5 (build thread) | ✓ (gdlint, wiki, changelog, touched tests; CI green on ebf01d9) | 6/8 Retry | Subway and Woodland PTB unmeasured; three comment lines over 120 |
| 2026-11-18 | 2 | Opus 5.5 (build thread) | ✓ (as above) | ? | – |

Agents: QA 42k tokens, performance 21k, critic 38k (attempt 1), changelog 24k.

## What the bots showed

Bot matches, 6v6, Normal, seeds 1 to 32 a field and mode, respawns as each mode plays them (a scratch runner over
`MatchRunner`, four jobs in parallel). The baseline is main b0c5761, from the Beta 2 pass (16 seeds; Woodland PTB 32).

| Field | Attack / Defend: attackers | main | Plant The Bomb: attackers | main | Band |
|---|---|---|---|---|---|
| Depot | 55.1 % ±3.2 (243 rounds) | 50.9 % | 45.9 % ±3.3 (229) | 51.2 % | A/D 38–67 %, PTB 40–65 % |
| Woodland | 42.3 % ±3.2 (241) | 44.7 % | 48.5 % ±3.2 (237) | 49.4 % | 40–65 % |
| Subway | 49.8 % ±3.3 (235) | 51.3 % | 59.1 % ±3.2 (242) | 54.9 % | 40–65 % |

Rounds run out the clock: A/D Depot 44.9 %, Woodland 57.7 %, Subway 50.2 % (band with respawns ≤ 62 %); PTB Depot
18.8 %, Woodland 18.6 %, Subway 19.0 % (≤ 25 %). Every share is in its band; Depot moved both ways by about 1.5
standard errors, and Subway PTB rose a little (58.1 % on main's seeds 1 to 8) (Rushers forward on defence there meet attackers sooner; Careful carriers go in later). Easy and Hard
Plant The Bomb, 8 seeds: LEVELS. Easy and Hard Attack / Defend wait for BP10's per-level defender wait (#390), which
the Beta 2 pass measures with this change in.

## Decisions

- **The jobs are a table in `data/bots.md`** (Attack / Defend and Plant the Bomb), optional: without it, or a cell
  that can't be read, every bot plays the same jobs, and play is identical to main (scales of 1 multiply exactly,
  the draws are the same).
- **Defends forward / deep** changes which lane point a defender holds (RoundPlanner.defend_points) and who takes the
  round's pushed post (`_pushed_member`: the first forward one round the team from the draw, never a deep one). The
  pushed post's draws are unchanged.
- **Distances scaled, not roles forced**: Goes back from (×) and Takes the bomb or rope from (×) scale a bot's
  distance in the existing nearest-bot picks, so a much nearer teammate still takes the job; a personality only wins
  it from teammates a little nearer. Anchors go back at 1 (attempt 2: at 1.4 an Anchor by the pole stood while a
  Rusher ran back from 9 m, the critic's design risk).
- **With respawns every defender goes back** (respawn_retakers 6), so Goes back from only orders them with one life
  (Custom › Respawns Off); kept for that and for smaller teams.
- **Forward spawn chances** (Rusher 0.85, Anchor 0.35, Flanker 0.7, Careful 0.5) average the game's 0.6, so a team
  comes back forward as often as before. They apply only with sides; Elimination with respawns keeps 0.6 (QA).
- Card notes left as they were: they describe how each plays everywhere.

## Known issues left

None.
