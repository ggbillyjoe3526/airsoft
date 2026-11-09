# FL1 · Bots' flashes no longer blind their own teammates

**Review:** 1 attempt · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | Opus 5.5 (Dev 3 checklist thread) | 8/8 | 8/8 Accept (QA Pass, performance Pass) | – |

## What changed

Found while checking the 0.1 Dev 3 owner checklist without play (SF2's "bots never flash their own teammates"). In
whole bot matches on Depot (Attack / Defend, 8 seeds each at 6v6 and 8v8, Normal) bots' flashes dazzled 7 enemies and
4 teammates, one teammate at strength 98 for 3.4 s. Each caught teammate was clear of the bang when the bot chose the
throw, then walked toward it during the turn (up to `bomb_aim_time`), the windup and the fuse. Same seeds after the
fix: 3 enemies, 0 teammates (4 flashes thrown, against 9).

- **BotBombs** (`game/ai/bot_bombs.gd`): `_mate_sees` checks each teammate where it stands and where its pace takes
  it by the bang (velocity × the throw's windup and the flash's fuse, `GrenadeConfig.windup + flash_fuse`), with the
  same `flash_mate_clear` and `flash_mate_sight` rules. `_flash_at` keeps the planned bang on the bot
  (`Bot.bomb_bang`), and the press checks it again: a teammate now in the way drops the throw and keeps the flash.
- **Tests** (`test_bot_bombs.gd`): a teammate walking in from 16.5 m stops the throw (standing still, it doesn't); a
  teammate stepping near the bang during the turn gives the throw up and the flash is kept. Both fail on `main`.

## Decisions

- **Lead by the windup and fuse only, not the turn** (default): the press-time check covers the turn, and a longer
  lead would refuse throws for teammates merely passing by.
- **A dropped throw waits its usual roll gap** (`bomb_roll_gap`) like a failed roll: no new rule.
- **No change to how far a flash reaches or who it dazzles:** the player's own flash still blinds teammates (SF1).

## Known issues left

- A bounce off something the arc didn't foresee can still put the bang where a teammate is; not seen in the probe.
- The lead looks at where a teammate will be by the bang, not its nearest pass; one crossing the bang's spot with the
  line blocked at both ends could slip through (critic advisory, rare).
- Bots' flashes are rarer (9 thrown to 4 on the same seeds): the owner judges in play whether they still matter.
