# PS1 · Bot personalities take jobs in Attack / Defend and Plant The Bomb

**Review:** 3 attempts · critic Accept ?/8 · qa Pass · performance Pass

The owner's ask (2026-11-18): bots already had four personalities, but in Attack / Defend and Plant The Bomb they
differed only in pace, cover, bursts and lanes (the Anchor's hold and its flag watch are Elimination's). "Do that and
make sure the game is balanced": give each a job there (who carries and plants the bomb, deep or forward defence,
forward spawns) and keep the attackers' share in its band.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-18 | 1 | Opus 5.5 (build thread) | ✓ (gdlint, wiki, changelog, touched tests; CI green on ebf01d9) | 6/8 Retry | Woodland PTB and Subway unmeasured; three comment lines over 120 |
| 2026-11-18 | 2 | Opus 5.5 (build thread) | ✓ (as above; CI green on 53d754b) | 6/8 Retry | Normal rows not all on 32 seeds, Woodland PTB Hard unfinished, Subway A/D near 65 %; two long lines; `is_neutral`'s comment |
| 2026-11-18 | 3 | Opus 5.5 (build thread) | ✓ (as above; CI on the final head) | ? | – |

Agents: QA 42k tokens and 29k (re-check), performance 21k and 23k (re-check), critic 38k (attempt 1), changelog 24k.

## What the bots showed

Bot matches, 6v6, respawns as each mode plays them, a scratch runner over `MatchRunner` (four jobs in parallel); the
attackers' share of rounds. Main is the Beta 2 pass's figures on main (16 seeds unless named), or main's behaviour on
the same seeds (this table with the personality table cut, which plays exactly as main).

The build moved five things out of line, each found by turning one job off at a time against main's play on the same
seeds:

| Found | Measured | Cause | Fix |
|---|---|---|---|
| Plant slower | Woodland Hard PTB 39.7 % (main 50.9, seeds 1 to 8), more rounds to the clock | Careful bots carried the bomb in: they walk and wait for the team | Flankers carry it (50.8 %) |
| Depot PTB down | Normal 40.5 % on 32 seeds (main 51.2) | Rushers holding their lane's second point every round (posts off: 52.8 %, Rusher's off: 49.6 %) | Forward now means first pick for the round's pushed post only (44.9 % on 32) |
| Easy PTB up | Depot Easy 73.7 % (main 43.3, seeds 1 to 8) | Flanker carriers on a lane of their own got past Easy defenders (carry off: 43.1 %) | A milder lean: Flanker 0.85, Rusher 1.25 (49.3 %) |
| Subway A/D up | 61.9 % on 16 seeds (main 51.3) | The carry lean on who raises the flag (lean off: 55.3 %) | No lean on the rope (52.1 % on 32) |
| A/D up on Depot and Woodland | Depot 63.1 % (main's play 50.9 %, seeds 1 to 16), Woodland 61.0 % on 32 | Forward spawn chances averaging the game's 0.6: the bots hit most (Rushers) come back forward most, so more of a team's comebacks are forward (spawn chances off: Depot 54.7 %) | Chances a little lower in Attack / Defend only: Rusher 0.7, Anchor 0.3, Flanker 0.6, Careful 0.4 (Depot 50.0 % on the same seeds); lower in Plant the Bomb too took its Hard attackers down 10 points, so it keeps the even set |

Final table (Normal on 32 seeds; Easy and Hard on 16 or 8):

| Field | Mode, level | Attackers | Main | Band |
|---|---|---|---|---|
| Depot | A/D Normal (32) | 51.8 % ±3.3 | 50.9 % (16) | 38–67 % |
| Depot | A/D Hard (16) | 52.3 % | 47.9 % | 40–60 % |
| Depot | A/D Easy (8) | 44.3 % | – | 35–65 % |
| Depot | PTB Normal (32) | 48.1 % ±3.2 | 52.0 % (16) | 40–65 % |
| Depot | PTB Hard (16) | 51.9 % | 56.9 % | 40–60 % |
| Depot | PTB Easy (8) | 49.3 % ±6.0 | 43.3 % | 35–65 % |
| Woodland | A/D Normal (32) | 49.4 % ±3.2 | 44.8 % (16) | 40–65 % |
| Woodland | A/D Hard (16) | 45.4 % | – | 40–60 % |
| Woodland | PTB Normal (32) | 56.2 % ±3.2 | 50.9 % | 40–65 % |
| Woodland | PTB Hard (24) | 49.7 % ±3.8 | 49.2 % | 40–60 % |
| Woodland | PTB Easy (8) | 55.7 % ±6.4 | – | 35–65 % |
| Subway | A/D Normal (32) | 48.5 % ±3.3 | 51.3 % (16) | 40–65 % |
| Subway | A/D Hard (16) | 44.4 % | 52.8 % | 40–60 % |
| Subway | A/D Easy (8) | 52.7 % | – | 35–65 % |
| Subway | PTB Normal (32) | 57.3 % ±3.2 | 54.4 % (16) | 40–65 % |
| Subway | PTB Hard (16) | 47.9 % | – | 40–60 % |
| Subway | PTB Easy (8) | 57.1 % ±6.2 | 56.7 % | 35–65 % |

Attack / Defend rows are on the final chances (Normal here; Hard and Easy by the Beta 2 pass on 0589f0b, whose Attack /
Defend play is the final head's). Plant the Bomb rows play the bomb column's set, which 53d754b and earlier heads
shared: Normal Depot and Subway on the final head, Woodland Normal and Easy and Depot and Subway Easy on the heads
before the rope change (Plant the Bomb has no rope), Hard by the Beta 2 pass on 53d754b with #393 (Depot) and here on 24
seeds (Woodland). Main is main's play on the same seeds where it has no seed count, else the Beta 2 pass's figures. At
Normal the clock ends 48 to 52 % of Attack / Defend rounds (band 62 %) and 12 to 15 % of Plant the Bomb rounds (band
25 %). Every row is in its band; Depot Plant the Bomb at Hard is the Beta 2 pass's
(its Hard bomb wait, `data/maps.md`).

## Decisions

- **The jobs are a table in `data/bots.md`** (Attack / Defend and Plant the Bomb), optional: without it, or a cell
  that can't be read, every bot plays the same jobs, and play is identical to main (scales of 1 multiply exactly,
  the draws are the same).
- **Defends**: `deep` (Anchor) always holds its lane's first point and is never the pushed defender; `forward`
  (Rusher) is the first pick for the round's pushed post (`RoundPlanner._pushed_member`) and otherwise holds what the
  plan deals. The pushed post's draws are unchanged.
- **Distances scaled, not roles forced**: Goes back from (×) and Takes the bomb from (×) scale a bot's
  distance in the existing nearest-bot picks, so a much nearer teammate still takes the job; a personality only wins
  it from teammates a little nearer. Anchors go back at 1 (critic attempt 1: at 1.4 an Anchor by the pole stood while
  a Rusher ran back from 9 m). With respawns every defender goes back (respawn_retakers 6), so Goes back from only
  orders them with one life (Custom › Respawns Off) or a small team.
- **Flankers carry the bomb** (0.85), Rushers leave it (1.25): Careful carriers were too slow, and a stronger Flanker
  lean too strong at Easy.
- **No lean on the flag rope** (critic attempt 2): the same lean on who raises the flag lifted Attack / Defend
  attackers (Subway 61.9 % on 16 seeds); without it Subway reads 52.1 % on 32. The raiser is picked by distance as on
  main.
- **Forward spawn chances, one column a mode.** Plant the Bomb: Rusher 0.85, Anchor 0.35, Flanker 0.7, Careful 0.5,
  averaging the game's 0.6. Attack / Defend: 0.7, 0.3, 0.6, 0.4, averaging 0.5. One set for both did not fit: the
  0.6 average lifted Attack / Defend attackers by 10 to 16 points (Depot 63.1 % against main's play's 50.9 % on the
  same seeds; spawn chances off 54.7 %), and the 0.5 average took Plant the Bomb's Hard attackers down 10 to 13
  (Depot 41.4 against 51.9 %, Woodland 35.4 % on 16 seeds, from the Beta 2 pass). They apply only with sides;
  Elimination with respawns keeps 0.6 (QA). The test holds the bomb column's average at 0.6 and the other's under it.
- Card notes left as they were: they describe how each plays everywhere.

## Known issues left

None of its own. Depot Plant The Bomb at Hard is out of band on main too (BP10's).
