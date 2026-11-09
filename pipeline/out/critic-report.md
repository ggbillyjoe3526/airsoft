Task: FL1 · Bots' flashes no longer blind their own teammates
Attempt: 1 of 4
Head: 283c5bf (checks passed on it; the only commit after QA's 025070b and performance's d53525f is the changelog note)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept
Evidence:
1. No task block; judged against the brief. Planning: game/ai/bot_bombs.gd:+169-183 `_mate_sees` checks each mate now
   and led by `windup + flash_fuse` (0.3 + 1.5 s); +110-116 `_flash_at` stores the bang on `Bot.bomb_bang` (bot.gd:+244).
   Throw time: bot_bombs.gd:+36-38 re-checks a FLASH at the press, drops it, flash kept. Probe: 0 teammates dazzled.
2. Contracts 1-9 untouched: pure static code in game/ai, acts through PlayerCommand, no new random draw.
3. Runs only after a passed roll (bomb_roll_gap) and once per press; Vector3 values only, no Array/Dictionary/Callable
   or strings; the led ray is skipped for a still mate (+180). QA and performance both Pass.
4. tests/unit/test_bot_bombs.gd:+268 (walking mate at 16.5 m: 1.8 s x 5 m/s brings it to 7.5 m, inside flash_mate_clear
   8; standing it is outside flash_mate_sight 16, so a throw) and +281 (mate placed 3 m from the planned bang after the
   decision; main has no press check, so it throws). Both fail on main by reading.
5. Rules in BotBombs; typed; lead comes from GrenadeConfig, radii from bot config; EPSILON is the file's own constant.
6. Bots refusing a flash that would catch a mate is honest, readable bot play; no tone or asset change.
7. `_caught` factored out cleanly; one field added. Nit: `bomb_bang` isn't cleared in Bot's reset (bot.gd:303-306),
   same as bomb_yaw/pitch; it's only read while bomb_kind is FLASH, which `_flash_at` sets with it. Not a defect.
8. Scope is the fix only; changelog note, wiki Grenades.md, PLAYTEST line and record updated.
Advisory (no fix needed now):
- The lead samples one endpoint (now + 1.8 s), not the closest approach: a mate crossing past the bang inside 8 m with
  the line to it blocked at both ends would slip through. Rare; it's also caught at the press.
- Flashes thrown fell 9 → 4 and enemies dazzled 7 → 3 on the same seeds, so bot flashes are now noticeably rarer.
  Small sample; worth the owner's eye rather than a change now.
Owner should test in the game:
- Play a few Attack / Defend rounds on Depot with bots on your team: no teammate (or you) gets flashed by a bot.
- Do enemy bots still flash corners often enough to matter, or do they now almost never do it?
- When a bot turns to throw and then holds the flash, does that pause look odd (stood still, turned, nothing thrown)?
