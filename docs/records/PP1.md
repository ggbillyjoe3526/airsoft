# PP1 · Preliminary Dev 3 pass: balance, bugs, QA and performance

**Review:** part 1 (#305) 2 attempts · critic Accept 8/8 · qa Pass · performance Pass; part 2 (#306) 1 attempt ·
critic Accept 7/8 · qa Pass · performance Pass; part 3 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Part | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|---|
| 2026-11-11 | 1 | 1 | build thread | targeted ✓, CI unit part 1 ✗ | 6/8 Retry | test_armory_cards read the list's dim; the next level's tiles dimmed; a stale row |
| 2026-11-11 | 1 | 2 | build thread | ✓ | 8/8 Accept | – |
| 2026-11-11 | 2 | 1 | worker | targeted ✓, CI unit part 3 ✗ then ✓ | 7/8 Accept | (non-blocking) the mid-ride stop limit had no row: added; the field areas check missed the Lift name: fixed |
| 2026-11-11 | 3 | 1 | build thread | targeted ✓ (QA ✗: 5 stale tests) | 7/8 Retry | QA Fail; the Grenades wiki page and the record's "no new system" |
| 2026-11-11 | 3 | 2 | build thread | targeted ✓ | 8/8 Accept | – |

The owner's preliminary run of the Dev 3 final passes (2026-11-10, "search thoroughly for any bugs, issues (quality,
balance, performance)", "check against all known issues"); the full passes run again after Subway's models and the
sounds. Six read-only reviewers swept the code since `0.1-dev.2` (Subway, the other maps, replicas and UI,
performance, a balance model of the data) and every `docs/KNOWN_ISSUES.md` row, the 2026-11-07 list, the BP7 and BP8
playtest notes and the Dev 3 checklist's partly checked items. Bot balance runs on every map (Normal 32 seeds, Easy and
Hard 16, both modes) ran alongside. The fixes ship in parts.

## Part 1: bugs, performance and docs

- **Door frames in their walls.** Every leaf hangs on its wall's face (`tools/depot/build_map.py`), but
  `DoorView._add_frames` put the frame at the leaf: 0.19 m proud on Depot's 15 doors, 0.3 m on Woodland's 0.5 m hut
  walls, and its jamb probe missed the wall, so the depth fell back to 0.3 m. The frame now finds the thinnest wall
  either jamb meets within `WALL_REACH` (0.1 m) of the leaf and sits in its middle. The DM1 depth test read the
  MultiMesh back, which is the identity headless, so it passed whatever; `frame_at()` gives tests the placed transform.
- **The Armory and old saves.** `ArmoryFacts` judged unlocked by level alone; LV15 moved items up a level and saves keep
  them, so a Dev 2 save at the old cap saw five owned items locked. It now takes `Progress.unlocked` and dims only
  items not owned; the count follows.
- **Button press.** A still press (Reduced motion) cutting a dip short left the button shrunk; it is reset at the cut.
- **Lamps and fixtures.** `LightFixtures` made a fresh Shader per match (the BP2 regression); it uses `CodeShaders`.
  `RoofView` kept flicker levels as 32-bit floats, so a low step never compared equal and the lamp was written every
  frame of a burst; 64-bit now.
- **The scope's shadow slots.** `OpticGlass` set only its atlas size, so its picture kept the viewport's 88 slots under
  Depot's 91 and Subway's 103 lit lamps; it takes `GraphicsApply.apply_slots` as the main view does.
- **Weapon rail keys** relabel on resume (`WeaponRail.refresh_keys`); the KNOWN_ISSUES row is deleted.
- **The Loadout's sheet and the wiki** give Spread from the hip (Spread × Hip spread): the Sniper Rifle read 0.10°, the
  tightest, when from the hip it is 0.60°. Pace and Spread moving rows show for a replica off ×1 (the Compact SMG); the
  KNOWN_ISSUES row on it is deleted.
- **Docs** that disagreed with the code: wading's noise (Maps, Movement), "a replica every five levels" (public players
  get one at 5 and 15), Woodland's "dry stream" (data/maps.md), the bot kits' personality lean and column sums
  (data/bot-kits.md), and three stale KNOWN_ISSUES rows (Subway on Medium, Depot's baked details, "row 104").

## Part 2: climbing and Subway's lifts

- **Props climbed (High).** CL1's climb checked only that a 0.6 to 0.95 m top ran on 1.5 m, so Depot's desks and sofa,
  Subway's benches and the Range's long crate could be climbed from an end, against the wiki and CL1's "never crates or
  props". `VaultConfig.climb_kinds` (`[floor]`) lists what a climb may end on; a top no listed block owns (the ground)
  still counts. Bots' climb links go through `Vault.plan`, so they follow. A sweep of every non-floor block on all four
  maps at 16 headings guards it; Subway's track pits still climb at 0.9 m.
- **A full lift held open (High).** A bot waiting at a car standing open but full pressed its button every tick (304
  presses in 3.5 s, a beep and a ping each), so the car never left. It presses only when the car isn't open there and,
  while it shuts, only with room aboard.
- **Riders in the doorway (Medium).** Riders' spots on a small circle sat as close as 0.16 m, so keeping apart pushed one
  into the doorway and held the doors. Riders stand in the corners by rank, 0.6 m in, and don't keep apart aboard.
- **Routes from a moving car (Medium).** A route planned mid-ride started at the nearest stop's landing, not the stop
  the car heads for; a hit player's walk-off began with the doors shut. Routes start at the car's destination and a
  walk-off waits for the doors.
- **Bombs in a car (High)** stayed in the shaft as the car left; they ride with it now.
- **A "Lift" area** over each well, so a contact in a car has a place name (it had none at two stops). The field check
  `areas` counts a name over a car at one of its stops as stood in, since a car's floor is no nav cell (CI unit part 3
  caught it).
- **Vault links' price** is each take-off node's own weight, not the first node's (a wet first node would price every
  vault ×8).
- MT2's three unlisted limits, and the mid-ride stop-on-the-way limit, are KNOWN_ISSUES rows.

## Part 3: balance

The balance review read every replica, part, optic, magazine and bot skill against data/stats.md, data/pool.md and
the bot tuning. Changes (data and tuning rows, and one new bot reaction, the flash dodge):

- **Parts are trade-offs, never straight upgrades.** The 11.1 V LiPo gave 15 % fire rate free: now 10 % recoil too.
  The Tight-Bore Barrel gave tighter groups and 3 % energy free: now −5 % energy (a little less reach). The Red Dot
  gave only its slight zoom: its raise time is 0.85 of the iron sights', the quick sight.
- **Sniper Rifle hip spread 6 → 10.** A snap shot from the hip at 15 m still hit nine times in ten; at 10 it is a
  coin toss, so the rifle is aimed.
- **Compact SMG hop-up cap.** `hop_up_max` 0.2 → 0.15 and `hop_up_dial` 0.65 → 0.85 keep its factory setting
  about where it was (lift 0.1275, was 0.13, the nearest dial notch; 27.46 m within 15 cm and 0.592 s to 30 m)
  and cut its best reach from 35 m to 31 m, so it can't be dialled into the AEG's 39 m band.
- **Bots turn from flashes.** Only a bot's own flash was turned from, so every flash the player threw blinded a bot
  facing it. `BotSkill.flash_dodge_chance` (Easy 0, Normal 0.3, Hard 0.6) is rolled once a bomb when someone else's
  flash in the air or landed is in its view and sight within `BotConfig.flash_dodge_reach` (16 m, flat); a win turns
  the bot away until `flash_wait_after` past the bang, as the thrower does (`BotBombs._judge_flash`). With two in
  view it judges the one that bangs sooner (QA).

Tests: test_bot_bombs (turns away on a win and is not dazzled; dazzled on a lost roll or out of sight; Easy never,
Hard more often than Normal; the sooner of two), test_sniper_rifle (reads `hip_spread`); QA's test_pp1_balance_qa
(the rows read, the parts' sums, the SMG's reach, its own, a teammate's, a far and a behind flash, two flashes);
stale rows in test_attachments, test_customise_parts and test_sn1_qa updated.

## Decisions

- **Not fixed, logged instead** (`docs/KNOWN_ISSUES.md`): the locker's silent run-in (a per-block noise is a bigger
  change than one block warrants), the button dip's lost edge click (the owner's "dips about its middle" look kept),
  the lamps' per-frame shadow redraw (needs a frame time from the owner's card first), SDFGI after a lamp switch, the
  Retro filter in the glass, and the stale map pictures (render again before the Dev 3 tag).
- **Flash dodge as a skill row** (default): Easy keeps 0 so the player's flash stays a sure thing against beginners'
  bots; Normal 0.3 and Hard 0.6 follow the smoke and flash chances' climb. Easy to retune in bot_tuning.tres.
- **A saved SMG hop-up** keeps its dial position, so under the new cap it lifts a little less than the player set
  (0.65 of 0.15 is 0.0975): the SMG is Dev content new in Dev 3, so few saves have one; not migrated.
- **The turn-away direction** is fixed when the bot first sees the flash (a flash seen in flight that lands past it
  can still catch it): kept simple, a playtest call.
- **A flash close behind a bot** (within `close_awareness`, 2.5 m, which `in_view` counts as seen) can be turned
  from too: a bang anywhere but straight behind still dazzles in part (`Grenades.dazzle_strength`), so turning away
  is right, at the cost of up to 1.8 s holding still (critic advisory, kept).
- **Balance changes stay small** (default): one step per row, as the full balance pass after the owner's playtest
  tunes them further.

- **`climb_kinds` is floor alone:** every shipped platform and dock top is kind floor. **Riders' corners 0.6 m in:**
  the body's radius (0.32 m) and the 0.2 m a bot stops short, with a margin.

## Balance runs

Every map, both modes: Normal 32 seeds, Easy and Hard 16 (reports in project files `playtest/pp1-balance/`). Depot
(before part 3) is in band throughout, four figures near an edge (Elimination Normal 47.9 / 52.1 % by team, Attack /
Defend Easy 61.5 % and Hard 40.3 % to the attackers). Subway and Woodland's figures outside within noise are the two
`docs/KNOWN_ISSUES.md` rows (Subway's at 32 seeds; Woodland's Hard timeouts were outside before part 3 too, 11.8 %
against 15.6 %, within noise). Nothing outside its band by two standard errors.

## Map pictures

The owner asked (2026-11-11) for the map pictures rendered again before the Dev 3 tag: all four (`assets/maps/*.jpg`
and `cards/`) from their spots in `docs/ASSETS.md`, on Forward+ with lavapipe. Woodland's far treeline is now green
(FT1) and Depot shows its worn lamps (DW1); the KNOWN_ISSUES row is deleted.

## Known issues left

- The rows above, each added to `docs/KNOWN_ISSUES.md`; and a bot replanning mid-ride whose car stops on the way walks
  out on the wrong floor's leg once (can wait).
- Part 3's owner questions (the Red Laser's cost, the GBB Pistol beside two rifles, the Hi-Cap rattle at a sprint,
  the Cyber Pistol beside the SMG): `docs/KNOWN_ISSUES.md`, playtest.
