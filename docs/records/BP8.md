# BP8 · William's 0.1 Dev 2 playtest (26 items)

**Review:**

- part 1 (bots): critic Accept 7/8 · qa Pass · performance Pass
- part 2 (replicas): critic Accept 8/8 (attempt 3) · qa Pass · performance Pass
- part 3 (match): critic Accept 7/8 · qa Pass · performance Pass
- part 4 (hud): critic Accept 7/8 (attempt 2) · qa Pass · performance Pass
- part 5 (arms): critic Accept 8/8 (attempt 3) · qa Pass · performance Pass

William's playtest notes of 2026-11-08 (26 items, before he tags 0.1 Dev 2) went out as a bug pass in parts by area.
The play list and the defaults taken are in `/mnt/project-files/playtest/bp8-summary.md`.

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-08 | part 1: 1 | Opus 5.5 | targeted + smoke; CI | Accept 7/8 | – (known issues rows and the same-spot helper added after) |
| 2026-11-08 | part 2: 1 | Opus 5.5 | targeted + smoke | Retry 6/8 | hip glass sampled the screen, not lined up; known issues rows; Pointman laser |
| 2026-11-08 | part 2: 2 | Opus 5.5 | targeted + smoke | Retry 7/8 | hip glass off-centre shrink and flat inspect lens; Variable Scope shoulder shading |
| 2026-11-08 | part 2: 3 | Opus 5.5 | targeted + smoke; CI | Accept 8/8 | – |
| 2026-11-08 | part 3: 1 | Opus 5.5 | targeted + smoke; balance 16 seeds; CI | Accept 7/8 | – (stale DECISIONS and KNOWN_ISSUES rows, SIMULATE button-only, named constants after) |
| 2026-11-08 | part 4: 1 | Opus 5.5 | 195-file round sweep + smoke | Retry 5/8 | banner left before GO, notes moved the rail, flash icon unreadable, A/D start not rendered |
| 2026-11-08 | part 4: 2 | Opus 5.5 | 223-file sweep + smoke; CI | Accept 7/8 | – (header text, chip-row test, plate alpha, pole marker after) |
| 2026-11-08 | part 5: 1 | Opus 5.5 | targeted + smoke | Retry 5/8 | forearm and sleeve in view, magazine not held, angled-grip wrist 41° |
| 2026-11-08 | part 5: 2 | Opus 5.5 | targeted + smoke | Retry 5/8 | pistol reload unseen, magazines hovering, sleeve on the way home |
| 2026-11-08 | part 5: 3 | Opus 5.5 | targeted + smoke; CI | Accept 8/8 | – |

## Part 1: bots (items 17 and 23)

- **17, Watching Here (new order).** A seventh order-wheel item, below Go There, with no key. It pings along the view
  (`PlayerCommand.ping_watch`, `SquadOrder.Kind.WATCH`) and puts a "WATCHING · 15 M" marker and floor ring on the
  spot (minimap diamond). Any order in force ends; the nearest free teammate (in play, not fighting, in cover or
  seeing a target, within `SquadConfig.watch_join_range` 45 m) stands beside you looking at it, and only one. The
  rest stay on the team plan and keep hunt picks and held angles out of `watch_radius` (8 m) round the spot. If the
  helper goes out, marking the same spot again brings a free teammate in (critic, part 1). It ends
  on another order, walking `watch_leave` (6 m) off, being hit, or round end. Tests: `test_bp8_watching_here.gd`,
  `test_bp8_bots_qa.gd`; four wheel tests moved to the seven-item wheel.
- **23, bots' running arms.** The exaggerated arms were the sprint with the replica put away (bots do it on calm
  sprints in their own half): fists pumped hip to chin, elbows flared. `tools/blender/bot-figure/gait/pump.py`
  re-makes `Holster_Sprint` from the hanging arm: smaller swing, elbows 77 to 92°, hands low and in, chest turn
  ±3.8°. Spliced into `human.glb` and `robot.glb`; rig, meshes and the 33fa48b shoulder weights unchanged; hit fit
  re-baked (sprint row moved under 1 cm). Running with the replica in hand uses the aim pose and was already calm.
  Test: `test_holster_sprint_arms.gd`. Pictures: `/mnt/project-files/playtest/bp8/bots/` (William: "looks good").

## Part 2: replicas (items 4, 5, 8, 10, 12, 26)

- **4, a laser on the AEG.** The Red Laser now fits the AEG Rifle (`side-rail` in `data/pool.md`). The AEG's parts
  file has it on the handguard's left side rail, just behind the left hand; the torch keeps the right rail, so the two
  never share one. 9,306 triangles. The Sniper doesn't take it. Bots' kits unchanged.
- **5, inspect with the muzzle to the left.** Every inspect pose turned the other way (`play_tuning.tres`,
  `ViewModelConfig`), so the left side faces you. The Sniper's inspect comes closer so the arms run off the foot of
  the screen (William: "perfect").
- **8, a bomb waits in hand.** The smoke and flash keys only bring the bomb to hand (`ready_grenade`). A click throws
  it; holding the button keeps the arm cocked at `GrenadeConfig.hold_at` (0.72, the arms' cocked key) until it is let
  go. Bots never wait. A hit while cocked drops the throw.
- **10, scope glass at the hip.** At the hip the 2x Scope's and Variable Scope's lens shows the field behind it,
  lined up, tinted with a reflection band; the zoomed view and reticle only aimed. A glass camera keeps the main
  camera's transform and draws only the lens's square of the view (`PROJECTION_FRUSTUM`, `frustum_offset`), with
  SSAO, SSIL, SDFGI, SSR, glow and volumetric fog off; reflection probes sit on a layer it skips
  (`AreaProbes.LAYER`). Below Mesh detail Medium (Low) no camera draws: the lens is a still light sky-grey tint.
  Own shader `optic_glass_hip.gdshader`; no shader copies the screen.
- **12, BBs from the muzzle.** `BBView.before_muzzle` hides your own BB while it is still short of the muzzle plane
  (turning, or aimed down a pistol's sights). Drawing only; the sim's ballistics unchanged.
- **26, a minimal Variable Scope.** Rebuilt in `attachments.py`: no rails, fibre sight, rear sight or illumination
  dial; one small dial on the turret housing; the collar's shoulder lofted smooth. 8,022 triangles; `aeg.glb` 2.99 MB
  of its 3 MiB cap.
- Tests: `test_bp8_replicas.gd` (20), `test_bp8_replicas_qa.gd` (24, incl. a world point landing on the same pixel
  through the main view and the lens, off-centre). Tool: `tools/render_replica_view.gd`. Pictures:
  `/mnt/project-files/playtest/bp8/replicas/`.

## Part 3: match (items 2, 7, 16, 20, 22, 24, 25)

- **2, any two bombs.** Two grenade slots per loadout, each Smoke or Flash, picked on the Loadout page (one of each
  by default). Saved loadouts from before read as one of each; bots carry what their kit lists.
- **7, louder bombs.** The smoke pop +6 dB, the flash bang +4 dB with a 2.2 s echo tail. Sound status updated in
  `/mnt/project-files/audio/sound-status.md`.
- **16, a longer flag.** The raise takes 7 s (was 5 s), then a raised flag must hold 3 s before it wins (it won at
  once). A defender alone on the rope resets it; both teams on it pause it; a flag held at the buzzer plays on in
  overtime. Balance at 7 s / 3 s (Attack / Defend, Normal, 6v6, 16 seeds, bushes in): Depot attackers 52.6 % ±4.7,
  Woodland 57.4 % ±4.6, The Street 49.1 % ±4.7, all in band (`FlagConfig`).
- **20, Attack / Defend by default.** `MatchOptions.DEFAULT_MODE`; a map that can't play it falls back to Elimination.
- **22, a still camera at round end.** The view holds still once the round is over, alive or watching a bot.
- **24, SIMULATE.** A Gameplay setting, off by default. With it on, a SIMULATE button shows during the round-end skip
  and settles the rest of the round with a seeded roll (more players left usually wins; attackers are helped by flag
  progress). Button only: a second click keeps skipping. The fast-forward skip is unchanged.
- **25, bushes.** Inside a bush everyone moves at 0.75 pace, and running steps sound as leaves heard 1.75 times as
  far (`MovementConfig`, `NoiseConfig`, `Foliage.holds`, no allocation). Ferns count too.
- Tests: `test_bp8_match.gd`, `test_bp8_match_qa.gd`; nine menu tests for the new default. Pictures:
  `/mnt/project-files/playtest/bp8/match/`.

## Part 4: HUD (items 1, 3, 13, 14, 15, 18, 19, 21)

- **1, LVL.** The level chip reads "LVL 4", not "LV 4" (`en.po`).
- **3, grey switches.** An off switch is a plain grey outline with one small grey knob (`MenuSwitch.colours`).
- **13, the weapon rail.** The ammo panel is compact (no replica name, no bomb icons). A rail sits just above it on
  the right: one row per slot (keys 1, 2, 4, 5 at the right, no names, no counts), model pictures for the replicas
  and one 44 px icon per bomb carried on a light plate; the one in hand is lit with a teal edge. RELOADING, a bomb in
  hand and the hop dial rise above the rail, so it never moves. Two of one kind show as two icons in one row.
- **14, 3-2-1-GO.** Every round starts held (`RoundState.hold`): you can look round but not move, fire, swap or
  reload; bots wait; the clock and time in play don't run (`is_live()` false; `under_way()` true for pole cues).
  `ROUND_COUNT` and `ROUND_GO` drive a plate under the round banner (`HudCountdown`), and the banner stays up through
  GO. Pause freezes it and hides the plate. `Round.end_countdown` emits GO; the Dev end-the-round cheat runs the
  clock out and the next step gives one GO and ends the round. Tests that act in a live round call
  `RoundHold.release`.
- **15, the whistle.** It blows on GO only. The first tick no longer queues sounds under the loading screen
  (`PlaySession.is_heard`).
- **18, HIT!.** Your own HIT! goes when the round result or scoreboard shows, and no longer shows while you watch a
  teammate (`hit_call_shown`). HIT! over an unhit bot was not reproduced otherwise.
- **19, the pause menu** is centred.
- **21, no overlaps.** Tab's board hangs under the score column, hides the middle stack and the flag warning, and the
  pole marker is not drawn through it or over the banner and countdown plate. Fire-mode chips drop to their own row
  when many magazine boxes would push them out.
- Tests: `test_bp8_hud.gd`, `test_bp8_hud_qa.gd` (14), `test_bp8_hud_round2.gd`; a 223-file sweep of round, HUD and
  PlaySession tests passed. Pictures: `/mnt/project-files/playtest/bp8/hud/` (William: "great" on the rail).

## Part 5: first-person arms (items 6, 9 and 11)

- **6, the left hand on a grip.** With a Vertical Grip fitted to the AEG or the Sniper the left hand wraps it; with
  an Angled Grip the palm rests on its swept face, the wrist bent under 30° (23.7° AEG, 18.6° Sniper). Grip holds are
  their own clips in `arms.glb`; pistols take no grip.
- **9, the reload.** Each replica has its own left-hand reload clip, the length of its reload. The hand comes up
  from below the view, takes the old magazine out of the well with the fingers closed on it, carries it down out of
  view, brings the fresh one up in hand and seats it, then goes back to the hold; only the hand and wrist show. The
  replica's magazine bone rides in the hand between `ViewModelConfig.reload_carry` shares
  (`game/play/magazine_carry.gd`). The replica tips and lifts per replica (`reload_cant_by`, `reload_move_by`,
  `reload_rise`); the pistols tip up 0.9 rad so the well is in view. A cut reload puts the magazine home and the hand
  on the hold. The approved hold and fire clips are unchanged.
- **11, skin-only arms.** Settings › Dev › Skin-only arms (off by default, saved, switched live): bare hands, sleeves
  unchanged. 38,900 tris drawn with gloves, 33,772 skin-only (budget 40k).
- Tests: `test_bp8_arms.gd` (16, incl. both arms projected through the view at every reload key),
  `test_bp8_arms_qa.gd` (26, every cut of the carry). Tool: `tools/render_arms.gd`. Pictures:
  `/mnt/project-files/playtest/bp8/arms/` (William's OK before merge).

## Decisions

- **Watching Here is wheel-only.** William asked for a wheel option; a key would need a Settings row he didn't ask for.
- **"Free" teammate:** in play, not fighting, in cover or seeing a target; with none free nobody joins ("at most one").
- **It lasts until you walk 6 m off the spot you marked it from**, another order, a hit or the round's end.
- **AEG laser on the left side rail**, behind the left hand: the right side is hidden at the hip and in the new inspect.
- **The Sniper takes no laser:** it has no side rail and William asked only for the AEG.
- **A held bomb waits cocked at 0.72 of the windup**, the arms' cocked key, so it looks ready.
- **Low draws no hip glass camera:** a still tint keeps Low's frame rate; Medium and up see through.
- **Each bomb slot is Smoke or Flash, never empty:** the note says "equip two"; a new loadout is one of each.
- **A raised flag keeps counting its hold with nobody on the rope:** nobody pulls it down, so it stands; William's play decides.
- **SIMULATE is a seeded roll that counts for XP and records**, and is button-only so a double-click to skip can't simulate.
- **Attack / Defend falls back to Elimination** on a map with no pole.
- **The countdown runs every round**, with no beeps (the whistle at GO only), and not on the Range.
- **In the countdown you can look round but not swap or reload:** nobody acts until GO, one rule for player, bots and sim.
- **The rail shows keys 1, 2, 4 and 5 only** (3 is the holster), icons with no names, as William marked up.
- **An Angled Grip is held behind, palm on its swept face:** that is how the part is shaped to be held.
- **Skin-only arms use one mid skin tone**, set in the data.

## Known issues left

- The two rows in `docs/KNOWN_ISSUES.md` dated 2026-11-08: held angles (Hard bots only) and the holstered run's still arms.
- Replicas: the hip glass camera's second draw from Medium up (frame time unmeasured on William's PC), the pistol's
  torch and laser overlapping at night (pre-existing), and `aeg.glb` near its 3 MiB cap.
- Match: simulated rounds count for XP and records, and bot routes ignore the bush slowdown (rows dated 2026-11-08).
- HUD: rail key labels are read once a match (a rebind mid-match isn't shown); HIT! over an unhit bot not reproduced.
- Arms: a sleeve hem can show at a rifle's magazine well; loose fingers past short magazines; the pistols' tip is new.
