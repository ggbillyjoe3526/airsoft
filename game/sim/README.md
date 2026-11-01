# game/sim

The gameplay rules as plain data and static functions: no `Node`, no scene tree, no input, audio or renderer
(docs/ARCHITECTURE.md › Contracts 1). Each file is rewritten from the browser game's `legacy/browser/src/sim/` with its
tests ported to `tests/unit/`. Tuning comes from `game/config/` (`SimTuning`).

## The step

`Simulation.step(state, commands, dt)` advances a `GameState` by one 60 Hz tick. Per character: move (a Jump press at a
low obstacle vaults it instead; a vault under way follows its path), swing the legs, lean, settle the aim, then use the
replica (BBs leave from this tick's leaned eyes); a run into a noisy prop knocks it; then every BB flies, and one
landing hard on steel rings it; then the magazines in the air land; then the smoke and flash bombs fly, pop and go bang
(a press before the character moves puts its replica down; the release follows the replica); then the round flow, or in practice the range's targets. A hit character follows the
hit-calling routine instead of its command. Nothing is allocated per tick once warm (checked by `test_simulation.gd`
and, on the range, `test_range_map.gd`).

| File | What |
|---|---|
| `simulation.gd` | `Simulation`: the services the rules need (tuning, `WorldQuery`, `CharacterMover`, the map's ends) and `step` |
| `game_state.gd`, `character.gd`, `player_command.gd` | The state, one character, the one input every character acts through |
| `squad_order.gd` | The squad orders a command can carry (Follow me, Hold here, Regroup, Team plan), turned into events for the bots |
| `dev_cheats.gd` | `DevCheats`: the Dev settings that change play (ghost, bottomless magazines, bots hold fire, game speed), End the round now, and the match's record mark |
| `game_event.gd`, `sim_events.gd` | The tick's events (shots, hits, footsteps, rounds), pooled: the only channel to sound, HUD and effects |
| `seeds.gd` | Seeded streams: every random draw comes from the match's `RandomNumberGenerator` or one derived from its seed |
| `world_query.gd`, `ray_hit.gd`, `character_mover.gd` | What the rules ask the level, behind two interfaces (Contracts 4): rays, what is underfoot, what each of its boxes is (a skip, a crate), its bushes (`foliage`) and its bar railings (`railings`: `bb_ray` a BB's path, `ray_past_railings` a bot's shot, `sight_ray` the eye, SR1) |
| `foliage.gd`, `leaves.gd` | `Foliage`: a map's bushes, upright ellipsoids with no collider, and the leaves a line crosses (bot sight and fire, a BB's path a tick), filed in a grid; `Leaves`: a BB through leaves keeps 0.35 of its speed and spin a metre and is turned up to 0.5 rad a metre from the match's stream (WL5, FO1) |
| `prop_noise.gd` | `PropNoise`: noisy props (NP1): a run or sprint into one knocks it (PROP_KNOCK), a BB landing hard on steel rings it (PROP_RING), one quiet time a prop (`GameState.prop_quiet`), nothing random; the table is `NoiseConfig` |
| `sound_path.gd` | `SoundPath`: the share of rays from an ear to a character's knees and head that the level blocks, and a line stopping short of a surface; the bots' hearing and the player's muffling hear through the same walls |
| `railings.gd` | `Railings`: a map's bar railings (SR1), each a block's box of square bars between a top and a bottom rail (RailingConfig); the first bar or rail a BB's path crosses, filed in a grid, and each run's parts for drawing |
| `box_world.gd` | A level of boxes answering both interfaces without a physics engine, for headless tests and tools |
| `map_end.gd`, `spawn_point.gd` | A map's two ends: spawns and dead-zone spots |
| `movement.gd`, `accuracy.gd`, `aiming.gd`, `footsteps.gd` | Paces, crouch and jump; spread by stance and motion; aiming down sights; footsteps and landings (further on gravel and steel plate: the event's carry) |
| `lean.gd` | Q / E held: the one lean geometry (eyes, BB origin, hit volume, camera, figure, bot vision), stopped short of walls |
| `vault.gd`, `vault_state.gd` | Jump at a low obstacle: finding one with level rays, the path through the mover, fire held after, presses kept |
| `armament.gd` | Magazines, the fire selector, the hop-up dial, the holster, trigger, reloads (a dry click reloads unless the command's `manual_reload` says the controller reloads by hand, RL2), draws, recoil and seeded spread |
| `mag_share.gd` | `MagShare`: the magazine hand-off (MH1). The command's `mag_hand_off` is one press: a toss to the nearest teammate asking you in reach (6 m, eye to chest, a clear line), else an ask if you are low (to the nearest teammate within 30 m with a spare that fits, keeping a full one), else MAG_REFUSED with its reason; asks stand 15 s, a toss flies 0.3 s + 0.05 s a metre in a pool of 6 (`GameState.mag_tosses`) and lands in the emptiest spares, or is lost. Each character's ask is `Character.mag`; the table is `MagShareConfig` |
| `grenade.gd`, `grenades.gd` | Smoke and flash bombs (SF1). `Grenade`: one bomb, a slot of `GameState.grenades` (a pool of 12 made once). `Grenades`: the command's `throw_grenade` is one press (in play, a live round or the range, not vaulting or throwing, one left, a slot free): the replica goes down silently (`Armament.put_down`), 0.3 s later the bomb leaves the eyes at 13 m/s along the view lofted 0.12 rad plus half your speed, 0.15 s later the replica is drawn at 0.6 of its draw time (a holstered one stays away, a torch comes back on); the throw lets go of trigger, sights, reload and switch (`throwing_command`), a hit drops it with the bomb kept. A bomb falls, bounces (GRENADE_BOUNCE), rolls and settles; a smoke pops at 1.2 s and smokes 18 s, an upright ellipsoid 4 m across and 2.2 m up that grows over 2.5 s and thins over the last 3 s, which BBs fly through and bots can't see through (`smoke_depth`); a flash goes bang at 1.5 s and dazzles everyone in play with a clear line from the eyes (`Character.dazzle_left`): whole within 6 m, none past 22 m, less looking away (a quarter looking straight away), 0.5 to 3.5 s. Each character's bombs are `Character.grenades` (one of each a round; on the range they come back); the table is `GrenadeConfig` |
| `torch.gd` | `Torch`: the weapon torch on the replica in hand (`Armament.lights`, night only), switched by the command's `toggle_torch` with a `TORCH` event; out when holstered, on a replica without one, when hit and at each round start |
| `bb.gd`, `bb_pool.gd`, `air_model.gd`, `ballistics.gd` | BBs in flight: drag by Reynolds number through the moving air, hop-up's Magnus lift, one midpoint step a tick |
| `hit_facts.gd` | `HitFacts`: what the "What got you" card says about a hit on you (where from, how far, moving, held angle, time in view), one record kept by `BotController` |
| `wind.gd` | The match's breeze, drawn from its seed each match, with gusts and a slow veer |
| `ricochet.gd` | A BB bouncing off concrete and steel; whether a bounced BB knocks anyone out is the match's rule |
| `hitbox.gd`, `bb_step.gd` | The hit volume (head, chest, hips leaning; swinging legs) and each tick's BB flight against the level, bushes (0.6 m of leaves over a flight stops a BB) and bodies |
| `elimination.gd` | Hit calling: alive, calling, walking off, leaving, out |
| `round.gd`, `round_state.gd` | Rounds in Elimination and Attack / Defend: clock, score, half time, reset, match over; the flag's time-out and overtime; Elimination's overtime flag at the buzzer; the practice switch (no rounds, no clock) |
| `range_target.gd`, `range_targets.gd` | Practice range targets: steel plates (front only, on posts), figures with a player's hit volume that fall and rise, pop-ups, movers and swingers on seeded times; BBs stop on them as `TARGET_HIT`; full spares in practice |
| `range_challenge.gd` | The range's timed challenge: ready on the START plate, a counted-down start, lit targets picked from the match's stream for a timed run, cues as `CHALLENGE` events, and the run's best (none with a Dev cheat on since START) |
| `flag.gd`, `flag_state.gd` | Attack / Defend's flag: attackers at the pole raise it, defenders pull it down, both hold it still |
| `overtime_flag.gd` | `OvertimeFlag`: Elimination's overtime flag (OV1): up at the map's spot when the clock runs out with both teams in play (an OVERTIME event), the first team with a player in play within reach of its foot wins the round (`RoundEnd.OVERTIME_FLAG`), both teams there hold each other off, untouched for `OvertimeConfig.time` a draw played again |

## Not yet

The walk-off route goes round cover on the map's nav grid (`Simulation.nav`, game/nav/); without one it is one straight
leg.
