# SN3 · Balancing the Sniper Rifle, its springs and the Variable Scope

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-03 | 1 | Opus 5.5 (bug pass thread) | ✓ | Retry 5/8 | Woodland 7v7 / 8v8 and every field's Attack / Defend unmeasured; Depot's two rows out of band unexplained; BP3 tags; no null guard in `bolt_waits`; the bench not in the tests README |
| 2026-11-03 | 2 | Opus 5.5 (bug pass thread) | ✓ | Accept 8/8 | – |

## The ask

The owner, 2026-11-02: once the UI redesign, the Sniper Rifle and "no full auto indoors" had merged, check all three
fields are still fair and balanced, above all with the Sniper Rifle's springs and the Variable Scope; change a map if
need be, with default choices noted for him to check.

## How it was measured

`tests/balance/sniper_bench.gd` (dev only, never shipped): seeded Normal bot matches on each field at 5v5 to 8v8, once
with the shipped kits (Dev content off, no rifle) and once with Dev content on and the kit table given a Sniper row for
each spring and the Variable Scope, so about a quarter of the bots carry the rifle. Per field and size it writes the end
(Elimination) or attackers' (Attack / Defend) share of decided rounds; per kit, hits for each hit taken and the median
hit range. 8 seeds a row, so a row's share is good to about ±6 points. Bands: 45 to 55 % (Elimination), 40 to 65 %
(Attack / Defend).

## What it found

- **Out past bot sight.** The rifle keeps its BBs within half a metre of the aim to about 54 / 57 / 59 m (M130 / M140 /
  M150) and hits out to about 63 to 67 m; a field's bots see 55 m (Depot, The Street) or 60 m (Woodland). A player
  holding over could pick bots off from where none could see them.
- **Sniper bots wasted their shot.** A bot's first aim at a fresh contact is off to one side on purpose, so a burst
  walks on; the rifle has one shot and then a 1.25 to 1.39 s cycle, so it threw it away.
- **The Street leaned further north.** Its known north lean (TS1) grew from about 52 % to about 64 % with sniper bots (8 seeds a size).
  A watch on every hit showed most of the north's coming from the Path jog, where its middle anchor holds and looks
  45 m down the Path's straight at attackers with nowhere to stop on it. Snipers are anchors, so they made more of it.
- **Depot held, within the bench's noise; Woodland leaned a little.** Elimination, end 0's share with sniper bots (without them):
  Depot 42 (40) / 44 (48) / 59 (48) / 51 (48) % at 5v5 to 8v8, Woodland 55 (51) / 55 (52) / 58 (44) / 60 (47) %.
  Depot's 42 and 59 sit outside 45 to 55 % but within a row's ±6 points, on either side, with no lean that holds
  across sizes. Woodland's do lean, a little, to end 0 and more as teams grow: a can-wait known issue, as the rifle is
  dev content and no player meets sniper bots yet. Attack / Defend at 6v6, attackers' share with snipers (without): Depot 62 (67), Woodland 62 (67), The Street 53 (61) %, all in the 40 to 65 % band with snipers: they help
  the defenders a little. Depot's 67 without them is new (KNOWN_ISSUES).
- **Springs and scopes.** The M150 bots did best (about 1.0 to 1.2 hits for each hit taken, an AEG kit about 1.0); the
  M130 and the Variable Scope least (0.5 to 0.85). Bots keep the Variable Scope at 2×, so it only costs them its slower
  raise: a can-wait known issue, not tuned here. None of them outplays the AEG kits, so no spring or scope was changed.

## What changed

1. **A shooter is given away** (`BotHearing.reveal`, `BotSenses.sight_reach`): a BB landing by a bot, or a hit on its
   teammate within hearing, lets it make the shooter out to `revealed_view_distance` (70 m, past the M150's reach) for
   `revealed_for` (4 s). It still has to face them, see them clear and, at night, see them in the light.
2. **Sniper bots** (`BotCombat.scoped`, `bolt_waits`): through a raised scope a bot sees to `scoped_view_distance`
   (60 m) and its aim error is `scoped_error_scale` (half) of the hand's; past `hip_fire_range` a bolt-action bot holds
   its shot until its aim has settled (`bolt_settle_share` of its skill's settle time).
3. **The Street** (`tools/street/layout.py`): wheelie bins (1.15 m, crouch cover) halfway down the Path's straight, at
   x −10.25, z 25. With sniper bots The Street's Elimination went from 41 / 33 / 33 % for the south end (5v5 to 7v7)
   to 41 / 52 / 40 % and 42 % at 8v8; without them 6v6 stays at 45 %.

`MatchRunner.kits_now` lets a bench's tick watch know each bot's kit.

## Defaults taken (for the owner to check)

- **The Street gets wheelie bins on the Path** (the one map change). Its lean is smaller but not gone: about 56 % north
  with sniper bots, about 55 % without, as before (KNOWN_ISSUES). Tried and dropped: moving the south's middle
  anchor post to the Path kink (no change).
- A revealed shooter is made out to 70 m for 4 s, by the bot shot at and by teammates within hearing of a hit.
- Sniper bots see 60 m through the scope, aim twice as steady through it and wait for a settled aim.
- No spring, scope or rifle stat changed.
- Woodland's lean to end 0 with sniper bots (55 to 60 %) is logged, not tuned: the rifle is still dev content.

## Checks

- `tests/unit/test_sn3_balance.gd`: 65 m off a bot sees nobody until a near miss or a teammate's hit gives the shooter
  away, for a while and only that shooter; a sniper bot sees further only with its scope raised; a bolt-action bot
  waits for its aim past the hip range and never close in, an AEG never.
- `tests/unit/test_sn3_qa.gd` (QA): reveals cleared each round, none of a shooter already out or by a friendly hit,
  night and dazzle still hold, the bins leave the Path open both sides.
- The bench as above; `tools/check.sh`.
