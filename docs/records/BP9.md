# BP9 · The full pass before 0.1 Beta 1

**Review:**

- part 1 (bugs): critic Accept 0/8 · qa Pass · performance Pass

William's full pass before he tags 0.1 Beta 1 (owner, 2026-11-15 and 16): bugs, balance, performance, quality and
edge cases over the whole game, with a clean-out of unused files, a hunt for flicker (faces lying over one another),
the harsh shadows and the over-bright spots under Depot's lamps. It goes out in parts, one pull request each.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-16 | part 1: 1 | Fable 5.2 | lint, wiki, whole unit suite, smoke; CI | Accept 0/8 | – |

## Part 1: bugs

Two reviewers read everything merged since 0.1 Dev 3 (`9521dc0..4169998`) and every finding was checked against the
code before it was fixed. Eleven were real:

- **A tap of the order wheel's key with the mouse moving gave a side order.** Following someone with the sight, the
  wheel's pointer left the middle circle inside the tap, so letting go gave Follow Me (or nothing, between the
  columns) in place of Spotted. A tap is now told by its time alone (`OrderWheelPointer.held`,
  `ControlsConfig.wheel_tap`, 0.2 s), in Hover and in Click.
- **A tap stopped a burst and froze the view.** The key going down took the trigger and the mouse at once. Inside a
  tap the trigger, the aim and the mouse wheel now stay the player's (`PlayerInput._wheel_held` takes them only once
  the key is held past a tap), and what the mouse moved meanwhile turns the view when the wheel closes inside the tap
  (let go, a pause, a hit, the window losing the key: `_close_wheel`, `_turn_view`). Held past a tap the wheel is as
  before: its pointer has the mouse, fire and aim need a fresh press once it closes.
- **Defenders held one lane point short of their post.** Cover taken by a lane point on the way counted as the post's
  (`Bot.post_cover` now tells them apart; `BotMovement`), so a defender who ducked on the way stayed there for the
  round. They go on to the post. This moves where defenders stand: the balance figures are re-measured in part 2.
- **A bot dazzled in the middle of a burst fired the rest of it** (`BotBrain`: `stop_burst`).
- **How soon a bot noticed the target it kept was read from a nearer one's range** (`BotSenses.perceive`).
- **Spotted overwrote a teammate's fresher news of someone else** (`Spots.share`): a bot that saw another opponent
  within `hearing_contact_time` keeps that one in mind.
- **An order whose last carrier was hit ended without a word** (Cover Me above all). Its giver is told "Back to the
  team plan" once (`SquadOrderBook`, `SquadOrders.Notice.CANCELLED`); a round's start still clears the book silently.
- **The interface colour missed two rings:** a switch's focus ring and a button's press ring kept the colour they
  were made with (`MenuSwitch._draw`, `ButtonPress.play`).
- **Spotted's arrow stepped at the tick rate** while its figure moved smoothly (`HudSpotArrows.place` takes the
  frame's fraction of the tick, as the figures do).
- **"Try my settings again" after a safe start lost a Custom haze** saved before the haze had levels ("on"):
  `Settings.custom_rows_now` reads it as High, in the guard and in the save's own migration.
- **A colour picked in Settings opened over the Loadout or the Armory came back to Match.** The rebuilt menus return
  to the page the settings were opened over (`Main._rebuild_menus`), the Loadout saved first.

Tests: `test_bp9_wheel_tap.gd` (8), `test_bp9_bots.gd` (5), `test_bp9_menus.gd` (6), `test_bp9_qa.gd` (14, QA), a new
defender test in `test_bot_flag.gd`, and the wheel tests that meant a hold now hold past a tap
(`test_order_wheel_input.gd`, `test_cw1_qa.gd`, `test_so3_qa.gd`, `test_so4_qa.gd`, `test_so4_orders_hud.gd`,
`test_bp8_watching_here.gd`, `test_mag_hand_off_hud.gd`, `test_fm1_field_map.gd`).

## Decisions

- **A pull of the trigger inside a tap is a shot, in Click mode too.** The wheel is not up yet, so there is nothing
  to click on; the wheel takes the trigger only once it shows.
- **A flick made inside the tap still lands** if the key is then held past it: the wheel's pointer moves from the
  moment the key goes down, as before.
- **The notice for an order nobody is left to carry is the one for walking away from it** ("Back to the team plan"):
  the player's next step is the same.
- **A bot keeps its own news over a Spotted for `BotConfig.hearing_contact_time`,** the time its own sighting
  already counts for against a sound.

## Known issues left

- A tap is timed on the wall clock (CW1): a hitch over 0.2 s makes it a hold.
- How the tap feels with a real mouse (spotting while turning or firing) is William's check
  (`docs/PLAYTEST.md` › The pass before 0.1 Beta 1).
