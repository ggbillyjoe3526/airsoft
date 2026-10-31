# AB1 · Two flags in Attack / Defend

**Review:** critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-10-31 | 1 | thread | two-flag and flag tests pass; full suite on CI | Retry 6/8 | the highest flag, not the one going up, was in play (a flag started under a stalled higher one went unanswered) and the HUD's marker and warning could name different poles; docs promised otherwise; the ruling missing from DECISIONS; the letter's billboard had no prewarm (performance) |
| 2026-10-31 | 2 | thread | two-flag (15), flag, minimap and QA tests pass | Retry 7/8 | the pole in play flipped as a contested rope flipped to raising and back, so bots on it dithered and the gauge jumped |
| 2026-10-31 | 3 | thread | two-flag (17), bot flag, QA and squad order tests pass | Retry 7/8 | a defender on one pole's worked rope could be filled into the pole in play when that was the other one |
| 2026-10-31 | 4 | thread | two-flag (18), QA (13), bot flag, overtime bot and wider flag tests pass | Accept 8/8 | – |

## Goal

The owner's answer on the Depot concepts (2026-10-31): two flags, A and B, in Attack / Defend; the attackers raise
either. Third of four pull requests for the new Depot: DR1 the map (merged), DO1 doors (merged), AB1 two flags, DR2 the
CC0 dress.

## Approach

- **Data.** A map lists its poles as `flags` (a list of spots, flag A first, two at most, `Flag.MOST`); one `flag`
  still reads as one pole, so Woodland is untouched. `tools/depot/build_map.py` writes Depot's from `layout.py`'s
  `FLAGS`: A (44, -27) on A site, B (45, 28) on B site. `MapData.poles` holds them; `pole` and `has_pole` stay flag A's.
- **The rules** (`Flag`, `RoundState`, `Round`). `RoundState.poles` and `flags` (a `FlagState` a pole, sized each
  round in `reset_flags`, the same array kept so readers keep it); `pole` and `flag` are flag A's (setting `pole`
  makes one pole). `Flag.step_all` works each pole on its own, and either raised wins (CAPTURED); the buzzer's overtime
  runs while the attackers work either rope (`Flag.rope_worked`). `Flag.in_play`, `highest` and `nearest` pick a pole
  for the bots and the HUD; none allocates.
- **The pole in play** (`Flag.next_in_play`, one rule for the bots and the HUD): the one in play now is kept while its
  flag is worked (raising, pulling down or both) and no flag going up stands higher; else the highest flag going up,
  else the highest. So a flag started under a stalled higher one is in play at once (critic, attempt 1), and a rope
  that flips between raising and contested never swings it to the other pole and back (critic, attempt 2).
- **Bots.** The attackers draw a pole each round from the planner's seeded stream (`RoundPlanner.attack_flag`, drawn
  only with two poles, so one-pole maps play as before) and go to the pole in play, else the drawn one
  (`BotFlag.in_play`, `BotWorld.flag` and `flag_index`). A bot on the rope of the pole it was sent to keeps to it while
  that rope is worked (`BotFlag.on_worked_rope`, `pole_of`), and a raiser there stays raiser. Defenders are picked per
  pole (`pick_retakers`, `Bot.retake_pole`): first every defender already on a worked rope stays on it, then for the
  pole in play and any other with its flag off the bottom the nearest free ones make each up to `retakers` (critic,
  attempt 3). So with A fought over and B
  started by the player, the two at A stay at A and free defenders go to B. A bot in flag mode picks its spot again
  when its pole changes (`Bot.flag_pole`). A defender's post for its search leash is the pole nearest the end of its
  lane (`BotFlag.post_of`).
- **The view and the HUD.** A `FlagView` a pole; with two, each carries its letter over its top (a Label3D turned to
  face you, `FlagViewConfig.letter_*`, billboarded as the "HIT!" sign is so the prewarm's sign covers its shader;
  performance, attempt 1). The marker and the gauge follow the pole in play (the HUD keeps its own, `Hud.shown_pole`,
  else the pole nearer the camera, so the player you watch); the marker names it ("FLAG B", `HudFlagMarker.set_letter`, text built only when the
  letter changes). The warning shows while the highest flag going up is theirs and you aren't at its rope, and names
  it ("Their flag is going up at B!", built only when the pole changes), whichever pole the marker shows: with A fought
  over and B going up, the marker stays on A and the warning calls B. The minimap draws both (`Flag.MOST` slots made
  once).

## Defaults taken

- The marker shows one pole, not two, so two pinned plates never stack under the minimap: the pole in play, or the
  nearer.
- Attacking bots draw A or B evenly each round; their lanes are still dealt as before (they converge on the drawn pole
  once swept), and a flag started at the other pole pulls them there.
- The letters are off-white on the fittings' dark outline, off both team hues.

## Checks

- Locally: `tests/unit/test_two_flags.gd` (18), QA's `tests/unit/test_ab1_qa.gd` (13) and the flag, bot flag,
  minimap, map and Depot tests pass; gdlint, the wiki check and the changelog check pass. CI runs the full suite and
  the match guards (now with both of Depot's poles) on the merge head.
- CI: the Elimination match guards job timed out at 28 minutes on this head twice (once re-run), with the same
  rounds as DO1's passing run; `main` failed the same way since DO1 merged (run 41207911844). The file outgrew one
  job once Depot became the indoor hall with doors, so `ci.yml` splits it into four jobs, one a test (locally Depot at
  Normal alone ran about 20 minutes, Bots run low 6, Follow me 1).
- Reviews: critic Retry 6/8, 7/8, 7/8, then Accept 8/8; QA passed attempt 1, failed a re-check (a test still calling
  the old `spot`), then passed; performance failed attempt 1 (the letter's prewarm), then passed.
- For the owner to play: whether A and B read from across the hall and the spawn chicanes; raising B while your bots
  fight at A late in a round (does A's defender stay and another come to B?); whether the bots' A/B split feels varied;
  whether the marker (the pole in play) and the warning (the flag going up) ever confuse by naming different poles;
  whether the minimap's two unlettered poles are clear; whether the marker should show both poles at once.
