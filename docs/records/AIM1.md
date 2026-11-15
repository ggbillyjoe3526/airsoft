# AIM1 · Bots find you again when you step back out

**Review:** 1 attempt · critic pending · qa pending · performance pending

The owner's 2026-11-15 playtest note: on Normal "I could move out of cover for a split second and I get hit".

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (build thread) | – | – | – |

## What was wrong

A bot that loses sight of you keeps you as the same contact for `contact_grace` (1.2 s) and watches where you ducked.
Before AIM1, someone seen again inside that grace was answered with **no reaction at all** and with the aim **fully
settled**, because the settle clock ran on while you were hidden. So the first peek was fair (a reaction of 0.25 to
0.45 s on Normal, then BBs walked in from one side), but stepping out again a moment later was met at once by a
settled aim on the spot it was already watching. Past 1.2 s a peek was fresh again, which is why it felt random.

## The fix

Seen again after more than `BotConfig.reacquire_after` (0.25 s, longer than two sight checks) out of sight and within
the grace, the bot picks you up again (`BotSenses.perceive`): a short reaction of its own (`BotSkill.reacquire_time`),
never cutting short a reaction still under way, and its aim keeping at most `reacquire_settled` of its settle time's
settling, its first aim off to one side again (`BotAim.fresh_error`). The contact stays the same one: its first
sighting, the callouts and the What got you card are unchanged, and no radio call goes out. The reaction now settles
from `Contact.reaction_from` (the start of the latest reaction) instead of the first sighting (`BotAim.settling`).

| Level | Fresh reaction (s) | Picked up again (s) | Aim kept settled |
|---|---|---|---|
| Easy | 0.35 to 0.6 | 0.25 to 0.4 | 30 % |
| Normal | 0.25 to 0.45 | 0.2 to 0.32 | 40 % |
| Hard | 0.25 to 0.45 (0.18 to 0.28 pre-aimed) | 0.15 to 0.25 | 50 % |

## The numbers

`tests/balance/aim_bench.gd` (new, dev only): one bot holding still in the open, AEG Rifle from the hip, against you
behind a wall's end on a flat field, 200 seeds a case; "old" plays with `reacquire_after` off, which is the code before
AIM1. The share of trials it hit you:

| Case, 10 m | Easy before | Easy after | Normal before | Normal after | Hard before | Hard after |
|---|---|---|---|---|---|---|
| Step out 0.4 s (fresh) | 0 % | 0 % | 0 % | 0 % | 12 % | 12 % |
| Step out 1.0 s (fresh) | 6 % | 6 % | 36 % | 36 % | 74 % | 74 % |
| Out 0.4 s, back 0.5 s, out 0.4 s again (2nd peek) | 15 % | 0 % | 100 % | 4 % | 98 % | 28 % |
| The same, back 1.0 s | 69 % | 0 % | 100 % | 5 % | 97 % | 27 % |
| The same, back 2.0 s (past the grace) | 0 % | 0 % | 0 % | 0 % | 15 % | 15 % |
| Run across a 4 m gap at 4.2 m/s | 10 % | 10 % | 19 % | 19 % | 49 % | 49 % |

At 20 m the second peek went from 27 % and 37 % to 0 % on Normal (43 % and 39 % to 0 % on Hard); at 30 m it was already
near 0 %. Fresh peeks and crossings are unchanged at every range (same seeds, same numbers). Standing in the open, a
Normal bot's first hit takes a median 1.15 s at 10 m, 1.6 s at 20 m and 1.9 s at 30 m; Easy 1.7, 2.0, 2.2 s; Hard 0.5,
1.25, 1.6 s (in the bench you step out where it already looks, so Hard's pre-aimed answer shows).

## Decisions

- **Normal's fresh reaction and aim are left as they are.** The bench shows the first peek was already fair on Normal
  (no hit on a peek under 0.6 s at any range); the second peek was the fault. Changing both at once would hide which
  one he feels.
- **Hard punishes a re-peek of the same corner more than Normal (28 % against 4 % at 10 m).** It watches where you
  ducked (`peek_watch_time`) by design, "careful, not twitchier".
- **Turning back to an enemy it was not fighting is a re-pick-up too.** A bot refreshes only its chosen target's
  sighting, so after fighting a nearer enemy for over 0.25 s it pays a re-pick-up (not a full reaction) on the first
  one, though that one stood in view. It has to find them again; before AIM1 the same switch past the 1.2 s grace was
  already a full fresh reaction. Refreshing every enemy in sight would cost a sight ray each per check (QA's advisory).
- **0.25 s for `reacquire_after`:** sight checks run ten a second, so a single missed check (a pole crossing the line)
  is not a new pick-up.

## Verified

- Bot matches, `SEEDS=16 LEVELS=normal tools/balance.sh depot` (6v6): Elimination Alpha 49.6 % ±4.5 and the west end
  49.6 % (band 45 to 55), no round to the clock, median round 47.7 s, first hit 14.7 s at 14.5 m; Attack / Defend
  attackers 49.2 % ±4.4 (38 to 67), median round 42.6 s; Plant The Bomb attackers 37.7 % ±4.4, as before AIM1 (37.9 %,
  AUD1; its balance is another thread's). Both teams play the same rule, so the shares hold.

- `test_aim1_reacquire` (new): a second peek reacts again within `reacquire_time` with the aim kept at
  `reacquire_settled`, the first sighting unchanged; a 0.2 s flicker changes nothing; past the grace a fresh contact;
  a reaction under way is never cut short; each level up re-reacts no slower and keeps no less settled.

## Known issues left

- For up to one sight check (0.1 s) after you go behind cover a bot still counts you in sight and turns after where
  you are; it never fires through the wall (its line-of-fire check), so it is left.
