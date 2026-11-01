# game/ai

The bots: plain data and static functions, no `Node` (docs/ARCHITECTURE.md › Contracts 1). A bot is just another
controller: each tick it writes the same `PlayerCommand` the player's input fills, and the simulation plays it by the
same rules. Rewritten from the browser game's `legacy/browser/src/ai/` (Elimination and Attack / Defend). Tuning is `BotConfig`
and its `BotSkill` (`game/config/bot_tuning.tres`).

## What a bot knows

Only what it could: who it sees (a 120° view, 40 m, through no wall, BB or body of someone already out, but through
glass, which stops its BBs, BQ1; at night no
further than the light round them lets them be made out: 40 m lit, 25 m in the open, 10 m under the trees, 15 m
indoors, `NightField`; inside a lit torch's beam within its reach, 40 m, and anyone whose lit torch points within 60°
of it from as far), anyone within 2.5 m, and what it hears (gunfire, running and sprinting feet, landings, vaults,
a hit called; walls muffle it; a heard spot is a guess off by a little). Walking and moving crouched are silent. It
never reads a position it hasn't perceived. It reacts after a reaction time per new contact, its aim error settles
over a second and wanders, and it fires in bursts only on aim, never with a teammate (or someone out) in the line of
fire, a miss's flight past the target included. Hit calls are the simulation's: a bot that is hit calls it like anyone.

## How it plays

Each round the `RoundPlanner` gives each team a plan (split over the map's lanes, a pair on one, or all stacked) and
each bot a lane to walk from its end, holding at its points and keeping with its team; past the lane it hunts the
sectors its team checked longest ago. In sight of an enemy it fights (strafing), or first gets behind close crouch
cover and peeks over it, or round a tall corner by leaning; it never fires with a teammate in the line, or anywhere a
teammate could run to before the BBs pass (a sprinting bot also round its route's corners). Seeing someone with no
shot at them (through glass or leaves) for `no_shot_move_after`, it goes round to them as to someone out of sight
(BQ1). Shot at, reloading or empty, it takes cover. With the enemy gone it searches where it was last seen or heard, sometimes flanking. At night
it holds its lane points, hunts and takes hold cover out of the light pools.

In Attack / Defend (`BotFlag`) the attackers walk their lanes just past the middle, then make for the pole: the nearest
raises the flag, crouched at the rope, while the others guard it from crouch cover near by. The defenders hold their
lane's first or second point, go after only what they see or hear near the pole, and the two nearest pull the flag down
once it is off the bottom. Two defenders at one point stand side by side, or, playing as a team (Hard), in a crossfire
on the lane's next point.

In Elimination's overtime (OV2) every bot sets off for the overtime flag's foot once its level's reaction to it going up
is over (`BotSkill.overtime_reaction`; the controller draws it, and the once-an-overtime flank roll, as the flag goes
up), by the same flag mode: a fight comes first, a squad order stays in force, and a bot whose roll came up goes round
a side point first when far out. A personality that watches the flag first (`data/bots.md`) holds crouch cover by it,
aiming at it, for its seconds, unless it is the last of its team or `BotConfig.overtime_go_by` of the overtime is left.

Each team plays at its level (`BotConfig.skill_for`: Easy, Normal, Hard). Hard is careful, not twitchier: holding,
it aims at the corners someone would step out of (`BotAngles`) and answers someone appearing there sooner; near the
enemy it walks and slices corners, leaning past a near one; it watches where someone ducked out before going after them,
and with a threat in mind tops up only from cover. It plays as a team: it goes to trade a teammate it heard call a hit,
tells its teammates where it heard someone, moves along a lane in pairs (one waits while its partner moves) and pushes
late when its team is behind.

A teammate in play can order its bot teammates (`SquadOrders`, M22): the order travels as the giver's command, the
simulation turns it into an event, and the controller's `SquadOrderBook` hands it out. An ordered bot still fights
whoever it sees; the order replaces only where it goes between fights (before the pole, noises and the lane), it is
never picked for the pole, nobody waits for it and its personality stands aside. Follow me keeps each a spot behind the
giver's heading (pairs either side, rows back, on the giver's side of walls and level), at the giver's pace, a pace
faster or slower to close on it and sprinting when far behind, covering the giver's back once there. Hold here sends
them to the spot the giver looks at, side by side across their view, looking their way. Go there held once all are
there lapses after `SquadConfig.go_there_quiet` with nothing happening round them, back to the plan (BQ1). Regroup sprints them back, each
turning to Follow me once close. The order in force given again cancels it (from the order wheel it stays), Team plan
ends it, and it ends when its giver is out and at each round start. Back on the plan, in Elimination the bot hunts from
where it stands; in Attack / Defend it takes up its post.

Bots share magazines (MH2, `BotMagShare`; the rules are the simulation's `MagShare`): a bot low on BBs for its primary
presses the hand-off through its command, which asks the nearest teammate within 30 m with one to spare (a bot never
asks for its pistol's). A bot asked, by a bot or by you, and free to bring one (not asking itself, not off to the pole)
sprints over while further than 8 m, walks on to within 3 m and presses once the catcher is in reach and in sight; it
serves its asks one at a time. A bot that asked a bot waits where it is; one that asked you walks up to within 3 m and
waits for your toss. Fights and cover come first, then bringing one, then a squad order and the pole, then waiting for
one; the same at every level. A bot presses at most once a second, and with nobody to ask it looks again after the
bot's 20 s gap, so no press is refused tick after tick.

Every bot has a name and personality from `data/bots.md` (`BotsFile`), drawn on the match's seed (`BotRoster`): a
rusher pushes in and never waits, an anchor holds its lane short of the middle until late and aims from cover, a flanker
takes a lane of its own and flanks more, a careful bot walks and clears corners. A personality changes how a bot plays
at its level, never how well (`BotPersonality`).

| File | What |
|---|---|
| `bot_controller.gd` | `BotController`: owns the bots; before each step one route search, then each bot's command; after it, hearing and the round's plan |
| `bot_world.gd` | `BotWorld`: what every bot thinks with (tuning, rays, nav grid, lanes, cover, everyone, the plan, the time, each team's hunt memory, the night field); moving a spot out of the light |
| `bot.gd` | `Bot`: one bot's own state (mode, contacts, aim, route, lane, cover, timers, the throw it is making) and its seeded streams (its own and its bombs') |
| `bot_brain.gd` | The tick: look, pick a mode (advance, fight, cover, search, flag, order), move, aim, fire, reload; dazzled by a flash (SF1), it ducks where it stands and does nothing else |
| `night_field.gd` | `NightField`: the dark on a field played at night (light pools by floor, the canopy grid, roofs), from the map's data once a match, and who stands in a lit torch's beam; how far someone at a point is made out |
| `bot_torch.gd` | `BotTorch`: the torch light the bots' sight reads, once a perception interval; each bot's switch by what it is doing (fighting within 20 m, the end of a search), held 1.5 s at least |
| `bot_bombs.gd` | `BotBombs` (SF2): a smoke when pinned in cover by someone at range, a flash round a corner before a push (where it lands before the bang and no teammate near would see it), then a look away until the bang; the skill's chance from the bot's own bomb stream, along an arc clear of the level |
| `bot_senses.gd`, `bot_hearing.gd` | Sight (view cone, walls, bodies, no more than 0.6 m of bush beyond close awareness, no more than 0.8 m of a smoke bomb's cloud at any distance, nothing while dazzled, SF1, the night's range, which part shows) and hearing (gunfire, feet and further on loud ground, hit calls, near misses, a knock on a noisy prop as a step, a ring off steel faintly, an enemy's flash bang or smoke pop (SF2); walls judged by `SoundPath`) |
| `bot_aim.gd`, `bot_combat.gd` | Turning, aim error that settles, lead; bursts, line-of-fire checks (no fire through more than 0.25 m of bush), reloads |
| `bot_holster.gd` | Holstering on a long, calm sprint through its own half, drawing again on a threat |
| `bot_angles.gd` | Held angles: the corners and doorways in view where someone would step out, from the level's walls alone |
| `bot_cover.gd` | Crouch cover and lean spots at tall corners that hide a bot from a threat |
| `bot_movement.gd`, `bot_routes.gd` | Lanes, holds, hunting, searching, strafing, keeping apart; planning nav routes within the tick's search budget and following them |
| `round_planner.gd` | Each round's team plans and lanes (a flanker's own, an anchor's short one, attackers to the middle, defenders their first points), and hunt spots from the team's memory |
| `bot_flag.gd` | Attack / Defend: each bot's side, which attacker raises the flag and which defenders pull it down, when a bot wants the pole; when it goes for Elimination's overtime flag, and where flag mode heads |
| `squad_orders.gd`, `squad_order_book.gd` | Squad orders: carrying each out (Follow me's spots and pace, Hold here's spot and each holder's place, Regroup); the orders in force, handed out and ended |
| `bot_mag_share.gd` | `BotMagShare`: the magazine hand-off's bot side (MH2): when a low bot presses to ask, which ask a bot takes, the walk over and the press to toss, a bot that asked waiting or walking up to you |
| `bot_roster.gd`, `bot_personality.gd` | Each bot's name and personality for a match; a personality laid over the level's skill, and its habits |
| `pings.gd` | `Pings`: the ping book (PN1), one ping per character, a press resolved into a spot (the floor in front of what the view met) or a contact (an enemy under the view the bots' sight rules let you see), kept 8 s and cleared each round, and a Contact call's mark; `Pings.take`, how a bot teammate takes one (a noise heard there, kept `ping_memory`) |
| `callouts.gd`, `callout_log.gd` | `Callouts`: what the bots call to their team (`data/callouts.md`), read off what they do after each step on a seeded stream of its own, never writing a bot or the state; `CalloutLog`: the calls said, a fixed ring the presentation reads |

Nothing allocates per tick once warm. Route searches (`NavGrid.find_route`) are queued round-robin and kept to
`NavConfig.search_budget` a tick (one, the browser's NAV.searchBudget counted in searches: AStar3D can't pause one), a
walk-off due taking the tick's first (`BotRoutes.plan`, WL2). At 6v6 on the old wood a bot waited at most 0.08 s for
its route (WL2; Woodland's routes since WR1: KNOWN_ISSUES).

## Callouts

After each step (`BotController.observe`) the bots put what they just did into words for their team, as
`data/callouts.md` says: a fresh sighting (Contact, Contacts), a noise while nobody on the team sees anyone (Heard), the
team's hits (Down, Last one), a reload under threat, setting off after someone (Pushing, Flanking, Checking), settling
at a hold, and the flag going up (Raising, Flag). One call a team at a time, at the file's pace; hit players never talk.
The calls go into `CalloutLog` and nothing reads them yet (CO2 shows them). The bots on your team also ask for you
(BQ2, callouts.md › Asks): Need help (fighting two or more, or defending the pole being raised), Go round (a stand-off:
a spot to the enemy's side) and Cover me (raising the flag), each pinging its spot in the ping book (`Pings.ask`) while
you are in play and far off, at most once in the Asks gap and a few times a round; no bot takes an ask. The director draws on its own stream, so a
match plays the same with the callouts or without (`tests/guards/test_callout_guards.gd`).

## Not yet

No pings and no magazine sharing (docs/KNOWN_ISSUES.md); callouts are not shown or heard yet.
