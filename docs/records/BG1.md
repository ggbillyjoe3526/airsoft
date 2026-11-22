# BG1 + AIM3 · Bots spread out into solos, pairs and trios; Normal locks on more slowly

**Review:** 1 attempt · critic CRITIC_PENDING · qa Pass · performance Pass

The owner's 2026-11-22 playtest, items 7 and 8: "bots stay too close together mostly in depot/subway ... they can
group up as a full team but it should be rare (unless the game mode/objective suits it). they can go solo or in duos
or trios", and "i'm seeing that i'm in their target for 0.9-1.4s. maybe push it to 1.5-2 ... easy difficulty feels
good to play. make sure the game still feels balanced in all maps/modes/difficulties."

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-22 | 1 | Opus 5.5 (build thread) | ✓ | CRITIC_PENDING | – |

## What was found

- **Bunching came from the bots' answers, not their lanes.** A noise, a teammate's radio call or gunfire sent every
  teammate in range to the same spot: on Subway's and Depot's tight floors that is most of the team. Hunters also
  picked spots by staleness alone, so two hunters often walked to the same corner. A whole-team stack on one lane was
  drawn in 1 round in 5.
- **The time in a Normal bot's view before its hit matched the owner's reading.** Bot against bot on Depot, the median
  time from a bot's first sight of someone to its hit was 1.27 s (quartiles 0.97 and 1.72 s), the same as the "What
  got you" card's 0.9 to 1.4 s. The aim bench (a still target in the open) had Normal at 1.25 s at 10 m, Easy at 1.77 s.

## The fix

- **A crowd cap (`BotSpread.crowded`, `BotBrain._choose_mode`).** A bot on its plan (walking its lane or hunting) goes
  after a noise or a call only while fewer than `search_crowd_max` (2) teammates are within `search_crowd_radius`
  (12 m) of the spot, or searching, fighting or in cover with their own threat within that of it. Otherwise it keeps
  to its plan, watching that way, and takes the call up once there is room. Never held back: a bot already within
  the radius of the spot, one that was fighting (its own threat), one joining its player's ping, a defender (its leash
  already keeps it near what it defends) and anyone at the pole or the bomb site (those modes come first).
- **Hunters fan out (`BotSpread.hunt_crowded`, `RoundPlanner.hunt_point`).** A hunt spot within `hunt_crowd_gap`
  (12 m) of a teammate in play, or of a hunting teammate's goal, counts `hunt_crowd_penalty` (40 s) staler.
- **A whole-team stack is rare.** Plan weights split 0.55, pair 0.4, stack 0.05 (were 0.4, 0.4, 0.2).
- **Normal locks on more slowly (AIM3).** Normal's reaction (and its pre-aimed one) 0.35 to 0.6 s (was 0.25 to 0.45,
  now Easy's), aim settle 0.95 s (0.6), first error 4.4° (4.0) and at least 0.7 m (0.6). Hard's surprised reaction
  follows to 0.35 to 0.6 s: the owner's ruling (2026-10-04) is that Hard is no quicker than Normal when surprised,
  and its edge stays the angle it holds (0.18 to 0.28 s). Easy is unchanged.
- **Subway's bomb defenders come back sooner (`data/maps.md` Bomb defender respawn, new column).** With Normal's
  slower lock-on Subway's Plant The Bomb attackers took 67 % (32 seeds, band 40 to 65): the defenders holding its
  sites lost their quicker first shot. A defender hit there now waits 3 s (5 s before), at every level but Hard, which
  keeps 5 s (the column at Hard). `MatchOptions.match_tuning` and `MatchRunner.sized_for` carry it.

## The numbers

Bot against bot, 6 a side, at Normal on 16 seeds a map and mode (4 on main and for Easy and Hard unless said).
"Stacks" is the share of the time a bot stands with 3 or more teammates within 10 m (a group of 4 or more); "seen"
is the median time from a bot's first sight of someone to its hit, as the "What got you" card times it.

| Field, mode | Stacks main | Stacks now | Seen main | Seen now | Attackers / first team now |
|---|---|---|---|---|---|
| Depot Elimination | 6.5 % | 1.9 % | 1.28 s | 1.60 s | 46.3 % |
| Depot Attack / Defend | 6.3 % | 5.2 % | 1.25 s | 1.62 s | 58.4 % |
| Depot Plant The Bomb | 8.8 % | 10.3 % | 1.23 s | 1.63 s | 51.8 % |
| Woodland Elimination | 6.5 % | 1.3 % | 2.03 s | 2.32 s | west 46.5 % (32 seeds) |
| Woodland Attack / Defend | – | 3.0 % | – | 2.08 s | 53.4 % |
| Woodland Plant The Bomb | – | 4.5 % | – | 2.13 s | 48.7 % |
| Subway Elimination | 8.2 % | 5.3 % | 1.15 s | 1.52 s | 48.8 % |
| Subway Attack / Defend | 21.2 % | 23.0 % | 1.22 s | 1.58 s | 60.0 % |
| Subway Plant The Bomb | – | 25.8 % | – | 1.52 s | SUBWAY_PTB |

- Over every map and mode the median "seen" went from 1.28 s to 1.73 s (quartiles 1.38 and 2.32 s). On the indoor
  fields, where the owner measured, it is 1.5 to 1.65 s.
- Knock-outs with 2 or more of the hit bot's teammates within 6 m fell on Depot Elimination from 4.9 % to 2.1 % and
  on Subway Elimination from 7.1 % to 4.3 %.
- Subway's Attack / Defend and Plant The Bomb still gather at the pole or site: the objective, as the owner allowed.
- The aim bench, a still target in the open (median seconds to the hit at 10, 20 and 30 m): Easy 1.77, 2.03, 2.30;
  Normal 1.25, 1.70, 2.10 on main, now 1.57, 1.93, 2.25; Hard 0.65, 1.43, 1.80.
- Easy (4 seeds): EASY_LINE
- Hard (4 seeds): HARD_LINE

## Decisions

- **The cap is 2 teammates within 12 m (Claude's default).** A fight then draws a trio at most. 10 m let bounced BBs
  decide 25.6 % of hits with Ricochets on in `test_bots` (the guard is 25 %; the owner kept it, 2026-11-22); 12 m
  gave 23.8 % and spreads a little more. See DECISIONS › Bots and balance.
- **Defenders are not capped.** Capped, Depot Attack / Defend attackers won 65.8 % (16 seeds); uncapped 58.4 %. The
  objective is what gathers them, as the owner allowed.
- **Normal reacts as Easy does, rather than reacting slower than Easy.** A Normal reaction above Easy's would turn the
  levels' order upside down (`test_bot_difficulty`); the rest of the slowdown is the aim's settling.
- **Subway's bomb defenders wait 3 s (Claude's default).** At Normal, 16 seeds: 5 s 66.1 % (32 seeds 67 %), 4 s
  63.9 %, 3 s 62.3 %. Turning the spreading off gave 63.8 % and the old aim 58.7 %: the slower aim is most of it, and
  the bomb never goes off there, so the fuse is no lever. Hard was 60.7 % at 5 s (4 seeds), so it keeps 5 s.
- **Easy and Hard were checked on 4 seeds a mode, Normal on 16 (Claude's default).** The cloud runs about 3 matches
  a core an hour; Easy changed only by the spreading, Hard by the spreading and its surprised reaction.

## Known issues left

- None.
