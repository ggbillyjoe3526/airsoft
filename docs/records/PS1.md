# PS1 · Bot personalities take jobs in Attack / Defend and Plant The Bomb

**Review:** 2 attempts · critic Accept ?/8 · qa Pass · performance Pass

The owner's ask (2026-11-18): bots already had four personalities, but in Attack / Defend and Plant The Bomb they
differed only in pace, cover, bursts and lanes (the Anchor's hold and its flag watch are Elimination's). "Do that and
make sure the game is balanced": give each a job there (who carries and plants the bomb, deep or forward defence,
forward spawns) and keep the attackers' share in its band.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-18 | 1 | Opus 5.5 (build thread) | ✓ (gdlint, wiki, changelog, touched tests; CI green on ebf01d9) | 6/8 Retry | Woodland PTB and Subway unmeasured; three comment lines over 120 |
| 2026-11-18 | 2 | Opus 5.5 (build thread) | ✓ (as above; CI on the final head) | ? | – |

Agents: QA 42k tokens, performance 21k, critic 38k (attempt 1), changelog 24k.

## What the bots showed

Bot matches, 6v6, respawns as each mode plays them, a scratch runner over `MatchRunner` (four jobs in parallel); the
attackers' share of rounds. Main is the Beta 2 pass's figures on main (16 seeds unless named), or main's behaviour on
the same seeds (this table with the personality table cut, which plays exactly as main).

The first build moved three things out of line, each found by turning one job off at a time:

| Found | Measured | Cause | Fix |
|---|---|---|---|
| Plant slower | Woodland Hard PTB 39.7 % (main 50.9, seeds 1 to 8), more rounds to the clock | Careful bots carried the bomb in: they walk and wait for the team | Flankers carry it (50.8 %) |
| Depot PTB down | Normal 40.5 % on 32 seeds (main 51.2) | Rushers holding their lane's second point every round (posts off: 52.8 %, Rusher's off: 49.6 %) | Forward now means first pick for the round's pushed post only (44.9 % on 32) |
| Easy PTB up | Depot Easy 73.7 % (main 43.3, seeds 1 to 8) | Flanker carriers on a lane of their own got past Easy defenders (carry off: 43.1 %) | A milder lean: Flanker 0.85, Rusher 1.25 (49.3 %) |

Final table (Flanker 0.85, Rusher 1.25, forward = pushed post; main with BP10 part 2 for Woodland):

| Field | Mode, level | Attackers | Main | Band |
|---|---|---|---|---|
| Depot | A/D Normal (16) | 58.6 % ±4.7 | 50.9 % | 38–67 % |
| Depot | PTB Normal (16) | 50.4 % ±4.6 | 52.0 % | 40–65 % |
| Depot | PTB Easy (8) | 49.3 % ±6.0 | 43.3 % | 35–65 % |
| Depot | PTB Hard (8) | 35.0 % ±6.2 | 32.8 % | 40–60 % (main is out too) |
| Woodland | A/D Normal (16) | 49.5 % ±4.7 | 44.8 % | 40–65 % |
| Woodland | PTB Normal (32) | 56.2 % ±3.2 | 53.3 % | 40–65 % |
| Woodland | PTB Easy (8) | 55.7 % ±6.4 | – | 35–65 % |
| Woodland | PTB Hard (8) | WOOD_H | 47.0 % | 40–60 % |
| Subway | A/D Normal (16) | 61.9 % ±4.5 | 51.3 % | 40–65 % |
| Subway | PTB Normal (16) | 57.0 % ±4.5 | 54.4 % | 40–65 % |
| Subway | PTB Easy (8) | 57.1 % ±6.2 | 56.7 % | 35–65 % |
| Subway | PTB Hard (8) | 52.5 % ±6.5 | – | 40–60 % |

Rounds to the clock stay in their bands (A/D 38 to 54 %, PTB 12 to 22 %). Subway A/D is the highest: with the carry
lean or the spawn chances off it reads 55.3 and 55.8 % (16 seeds each), so no one job lifts it beyond noise. Depot PTB
Hard is out of band on main as well; the Beta 2 pass (BP10) owns it. Easy and Hard Attack / Defend are measured by
the Beta 2 pass with BP10's per-level defender wait.

## Decisions

- **The jobs are a table in `data/bots.md`** (Attack / Defend and Plant the Bomb), optional: without it, or a cell
  that can't be read, every bot plays the same jobs, and play is identical to main (scales of 1 multiply exactly,
  the draws are the same).
- **Defends**: `deep` (Anchor) always holds its lane's first point and is never the pushed defender; `forward`
  (Rusher) is the first pick for the round's pushed post (`RoundPlanner._pushed_member`) and otherwise holds what the
  plan deals. The pushed post's draws are unchanged.
- **Distances scaled, not roles forced**: Goes back from (×) and Takes the bomb or rope from (×) scale a bot's
  distance in the existing nearest-bot picks, so a much nearer teammate still takes the job; a personality only wins
  it from teammates a little nearer. Anchors go back at 1 (critic attempt 1: at 1.4 an Anchor by the pole stood while
  a Rusher ran back from 9 m). With respawns every defender goes back (respawn_retakers 6), so Goes back from only
  orders them with one life (Custom › Respawns Off) or a small team.
- **Flankers carry the bomb and raise the flag** (0.85), Rushers leave both (1.25): Careful carriers were too slow,
  and a stronger Flanker lean too strong at Easy.
- **Forward spawn chances** (Rusher 0.85, Anchor 0.35, Flanker 0.7, Careful 0.5) average the game's 0.6, so a team
  comes back forward as often as before. They apply only with sides; Elimination with respawns keeps 0.6 (QA).
- Card notes left as they were: they describe how each plays everywhere.

## Known issues left

None of its own. Depot Plant The Bomb at Hard is out of band on main too (BP10's).
