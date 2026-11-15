# BC1 · The 0.1 Beta 1 checklist, cleared without play and rewritten

**Review:** pending

The owner, 2026-11-15 06:11: go through all 120 open items of `playtest/0.1-beta1-checklist.md` (the project's shared
files) and attempt each one; leave a smaller checklist of only the items that need him, each stating the issue and the
steps to check it. Other threads were, at the same time, balancing Plant The Bomb, rebuilding the Range's props,
reworking the replicas' materials, redesigning the maps, varying the bots' routes and reviewing the bots' aim, so the
items on those topics are held for them.

## What came of it

- **120 items in, 22 out.** The new list (`0.1-beta1-checklist.md`) has 22 items in five sittings: A on his graphics
  cards (6), B sound (2), C in his hands (7), D looks against his photos (6), E his own PC and save (2), plus a short
  "Held for the threads working on them now" section. The old list is kept word for word beside it as
  `0.1-beta1-checklist-before-2026-11-15.md`.
- **Two bugs found and fixed.** First, on the simpler renderer (Compatibility, Settings › Graphics › Renderer, the fallback
  for old cards) Woodland logged about 90 engine errors as it loaded ("Too many instances using shader instance
  variables"), and the models past the limit drew their worn feet from the wrong place. Compatibility holds shader
  instance uniforms for only 256 drawn instances (4,096 slots, 16 an instance), and Woodland draws about 300 worn
  models, each carrying its model's floor (`wear_floor`, SL2) as an instance uniform. Now, on Compatibility only, the
  floor is a material uniform and `LookMaterials.draw_worn` gives each material and floor one copy (props, door
  leaves, train parts); Forward+ and Mobile are unchanged. Test: `tests/unit/test_bc1_wear_floor.gd`.
  Second, bots' flashes still dazzled their own side (FL1's check): in 12 Depot Attack / Defend matches two of five
  dazzles were the thrower's teammates, standing 12 and 15 m from the bang, inside the thrower's own checks (the
  thrower judges where a mate stands and walks, but not one who turns or steps into view after the throw, nor where a
  bounce takes the bomb). Now the thrower calls it as it lets go ("Flash out!", a new callout event in
  `data/callouts.md`, said whatever the bot's own gap, shown in your hit feed), and a bot that sees its own side's
  flash looks away from it, at every level and with no roll, out to the flash's reach (22 m); an enemy's is still a
  roll of the skill's dodge chance inside 16 m. You, on a bot's team, get the call in the feed and look away yourself.
  Tests: three in `tests/unit/test_pp1_balance_qa.gd` (two more by QA), one in `tests/unit/test_callouts.gd`. The
  bots' five copies of the same character lookup became one, `BotWorld.character` (the critic's ask).
- **Checked without play** (below): every mechanical claim was matched to the tests that hold it (all green on `main`
  at a8e9863, CI run 43660324307), and where none did, checked fresh: whole bot matches, a load of every map by day
  and night on the simpler renderer, pictures of every menu, and the code.

## Fresh checks

- **Bots' flashes and their own side (FL1):** 12 whole Attack / Defend matches on Depot at Normal, bots only (seeds 1
  to 12): before the fix, 88 rounds, 7 bot flashes, 3 enemies and 2 teammates dazzled (the teammates 12 and 15 m from
  the bang, standing still and walking); after it, 85 rounds, 7 flashes, 5 enemies and no teammate dazzled. The
  existing whole-match test on Depot (3 seeds) reads 11 flashes, 7 enemies, 0 teammates, 1 thrower.
- **Every map loads clean:** Depot, Woodland, the Range, Subway and Stockade, each by day and at night, started in a
  match on the simpler renderer under xvfb and played a few seconds: no missing file, no script error and no engine
  error on any of the ten loads (after the fix below; before it, Woodland logged about 90), and every picture showed
  each map's models, none a grey box.
- **The menus at 1920 x 1080:** the Match page lists Depot, Woodland and the Range (no Street) and the modes in the
  order Attack / Defend, Elimination, Plant The Bomb, Practice, Attack / Defend picked; the Armory's track shows KIT
  and 1 to 10 with the arrows; the Loadout's boxes say SWAP; every Customise tab frames the whole replica.
- **The Cyber Pistol's card at the limit (PH1):** the Loadout sheet's energy row is
  `Ballistics.muzzle_energy` of the carried kit (`LoadoutFacts.sheet`), the same figure `test_ph1_physics` holds at
  exactly 1.0 J for 0.30, 0.36 and 0.40 g, printed to two places: it reads 1.00 J.
- **The licences (UC1):** `THIRD_PARTY_NOTICES.txt` lists only Poly Haven's plywood for Depot; the concrete entries
  there are Subway's ambientCG tiles.

## Each old item

Old number, item (task id), where it went, and how. "Checked" means checked without play; "→ A1" names the item of the
new list that carries what is left for the owner; "Held" names the thread working on it; "Gone" is a check that a
later change replaced.

| # | Item | Outcome | How |
|---|---|---|---|
| 1 | Bots' flashes and teammates (FL1) | Fixed; feel → C5 | The fresh 12-match count found 2 teammates dazzled; teammates now look away from their own side's flash (0 after). |
| 2 | Depot's hall shell (DH1) | → D1, A1 | test_dh1_hall_shell holds the shell's boxes; the floor choice and the look are his. |
| 3 | Depot's models in Woodland (DM1) | → D2 | test_dm1_map_models (frames in their walls' middle, flagpoles). The "plain boxes" note is gone (WG3, WG4). |
| 4 | Flagpole and the Range's skyline (FS1) | → D2, D6 | test_skyline, test_flag. The skyline's look by day and night is his. |
| 5 | The Range's models (RM1) | Held: Range props | Being rebuilt from his photo. |
| 6 | Depot's racking and props (RK1) | Checked; → D1, A1 | test_rk1_props, test_ricochet (drums and lockers ring and bounce BBs, barrels don't). Fun or annoying is his. |
| 7 | Woodland's structures (WG3) | → D2, A1 | test_wg3_woodland_models (boxes, stops, head room); the look against his photos is his. |
| 8 | Woodland's small props (WG4) | → D2, A1 | test_wg4_woodland_props; the night glow and the look are his. |
| 9 | The Street is gone (SX1) | Checked | test_sx1_qa (a saved Street pick opens Depot), test_dev_settings; the Match page picture. |
| 10 | Woodland's trees (WT1) | → D2, A1 | Collision unchanged (test_woods_view); the look is his. |
| 11 | Woodland's models (WG2) | → D2, A1 | test_wg2_woodland_models; whether he can still vanish in ferns is his. |
| 12 | White glowing marks in Woodland | Gone → A4 | The bridge railing fix (GL1, #274) merged; one check on his card. |
| 13 | North bridge glow (GL1) | → A4 | test_gl1; needs his card. |
| 14 | Sunlit Concrete light (SL1) | → D6, A1 | Needs his eye and the laptop. |
| 15 | Sunlit Concrete wear (SL2) | → D1, A1 | Shimmer and look need his card. |
| 16 | Depot's repainted roof (SL3) | → D1 | His eye. |
| 17 | Menus, HUD and replica paints (SL4) | → D6 | test_team_colours_apply; the look is his. |
| 18 | Lamp light (UG1) | → A2, A3 | test_lamp_lights; needs his card. |
| 19 | Lamps alone indoors (UG2) | → A3 | test_ug2_qa; needs his card. |
| 20 | Worn lamps (DW1) | → A3 | test_worn_lamps, test_dw1_qa; needs his card. |
| 21 | Eye adaptation (UG3) | → A3 | test_eye_adaptation; needs his card. |
| 22 | Ultra's finer light (UG4) | → A2 | test_fine_light; needs his card. |
| 23 | Wear marks (WM1) | → A6 | test_wear_marks, test_wm1_qa (no marks on boots); needs his card. |
| 24 | No sun's bounce under the roof (PT1) | → A2, A3 | test_ul2_underground_bounce; needs his card. |
| 25 | Unused models removed (UC1) | Checked | The fresh load of every map (no missing file), the licences above. |
| 26 | Scope glass at the hip (SG1) | Checked; → D4 | test_sg1_hip_glass_qa (down the barrel line, unchanged aimed, never through a wall). One look on his card. |
| 27 | Countdown beeps (CB1) | Checked; → B2 | test_countdown_beeps, test_cb1_qa. Loud enough is his. |
| 28 | Button clicks, SWAP (UB1) | Checked | test_button_press (dip, ring, reduced motion, edge click); the Loadout picture shows SWAP. |
| 29 | Silenced shots | Checked; → B2 | test_au1_loudness, test_sound_mix (−7 dB, high cut, half reach). Muffled enough is his. |
| 30 | The Compact SMG (CS1) | Checked; → C2 | test_compact_smg (18 a second, pace, spread, level 12, public). SMG bots up close: Held, bot aim. |
| 31 | The Compact SMG's model (CS2) | → D4 | test_smg_model_qa; the look is his. |
| 32 | Levels up to 15 (LV15) | Checked | test_lv15_qa (cap 15, a public item every level, old saves keep unlocks); the Armory picture. |
| 33 | Level track ten at a time (LV15) | Checked; → D6, E2 | test_lv15_track (pages, keys, focus); the picture. Window sizes → E2. |
| 34 | Subway, the metro station (MT1) | Held: map redesign | Its flags moved since (MB1); the layout is being redesigned. |
| 35 | Woodland's stream (WS1) | Checked; → D2, B1 | test_ws1_stream, test_ws1_qa (60 % pace, bots take the bridge, BBs stop). Splash sound and look are his. |
| 36 | Preliminary pass fixes (PP1) | Checked; → E1 | test_dm1_map_models (frames), test_pp1_sheet, test_bp8_hud (rail after a rebind), test_pp1_climb_qa, test_bot_lifts, test_lifts. His old save → E1. |
| 37 | Balance tweaks (PP1) | Checked; → C3 | test_pp1_balance_qa holds the numbers; the feel is his. |
| 38 | Bots turn from your flash (PP1) | Checked; → C5 | test_bot_bombs (turn rolls, Easy never). |
| 39 | Your recordings (AU10) | → B1 | test_au10_sounds, test_recordings hold them in place; the sound is his. |
| 40 | Subway's lamps and extras (SM5) | → D3 | test_sm5_qa (look only, nothing blocks). The name board note is folded in. |
| 41 | Subway's signs and posters (SM5B) | → D3 | test_sm5b_qa. |
| 42 | Subway's trains (SM1) | → D3 | test_sm1_qa, test_sm1_trains_qa, test_trains (glass stops BBs, seats are cover). Flag A's fairness → D3. |
| 43 | Escalators, lifts, stairs, railing (SM2) | → D3 | test_sm2_edges, test_sm2_transit. Whether escalators jam: Held, map redesign. |
| 44 | Ticket hall and concourse (SM3) | → D3 | test_station_hall_props. |
| 45 | Small fittings (SD2) | → D3 | test_station_detail, test_station_detail_qa. |
| 46 | Works gear and plant room (SM4) | → D3 | test_sm4_subway_models, test_sm4_facing; the plant room lit since AUD1. |
| 47 | Platforms like the Tube (TB1) | → D3, A5 | test_tb1_vault_qa. |
| 48 | Running tunnels arched (TB2) | → A5 | test_tb2_car_arch_qa. |
| 49 | First-person hands (HA1) | → C1 | test_ha1_* (holds, grips, no fade); the look is his. |
| 50 | The replica's movement in your hands (HA1) | → C1 | test_ha1_hands_motion, test_motion_scale. |
| 51 | Replicas of metal, polymer and wood (MQ1) | Held: replica materials | |
| 52 | Cyber Pistol's rounded grip (MQ1B) | → D4 | test_cyber_grip, test_mq1b_qa (torch clears the guard). |
| 53 | Parts made of what the real ones are (MQ2) | Held: replica materials | |
| 54 | Bombs and power sources (MQ2B) | → D5 | test_mq2b_qa. |
| 55 | The figures' gear (MQ3) | → D5 | test_mq3_qa. |
| 56 | Headwear, arm bands, boots (MQ3B) | → D5 | test_mq3b_qa. |
| 57 | The figures' faces (MQ3C) | → D5 | test_mq3c_qa*. |
| 58 | Each part with a job (RP1) | Checked; → C3 | test_rp1_balance holds every number and card line; the feel is his. |
| 59 | Still air indoors, breeze outdoors (PH1) | Checked; → C4 | test_wind (drift grows with distance), test_ph1_physics (indoor fields still, the pause menu line). Reads as wind → C4. |
| 60 | Gas in the cold (PH1) | Checked; → C4 | test_ph1_physics, test_aud2_simb (Customise in the field's air). |
| 61 | Hits on running targets (PH1) | Checked; Held: bot aim | test_ph1_qa (the sweep). Being hit while running is in the bot aim review. |
| 62 | Heavy BBs and long lobs (PH1) | Checked; → C4 | test_ph1_physics (0.40 g, a lob flies until it lands). |
| 63 | Site limit with heavy BBs (PH1) | Checked | test_ph1_physics and the Loadout sheet's code: 1.00 J. |
| 64 | Subway lit as underground (UL1) | → A5 | test_ul1_underground*; needs his card. |
| 65 | Subway's ceilings on Ultra (UL2) | → A5 | Needs his card. |
| 66 | GBB Pistol at 0.70 J (PH2) | Checked; → C3 | test_ph2_qa (reach, gases, under the Cyber). |
| 67 | Compact SMG at 0.85 J (PH2) | Checked; → C2 | test_ph2_qa (31 m, short of the AEG). |
| 68 | Saved loadouts after the hop-up change (PH2) | Checked; → E1 | test_ph2_qa, test_saved_loadouts; his own file → E1. |
| 69 | Plant The Bomb, attacking (PB1) | Checked; → C7 | test_plant, test_plant_play, test_pb1_ui (3.5 s, 30 s, the ring). The case is a model now (PB2). |
| 70 | Leaving the bomb to the bots (PB1) | Checked; → C7 | test_bots_plant (6 s, 10 m, carrier last, a dropped bomb taken up). |
| 71 | Defending and defusing (PB1) | Checked; → C7 | test_pb1_qa, test_bots_plant (half-way kept, bots wait inside 15 m). |
| 72 | Plant The Bomb on each map (PB1) | Held: Plant The Bomb balance | |
| 73 | Plant The Bomb in smoke (PB1) | Checked; → C7 | test_pb1_qa (given away inside 5 m with hands on the bomb, lost on letting go). |
| 74 | The bomb and the wire cutters (PB2) | Checked; → D5 | test_pb2_qa, test_plant_models. |
| 75 | Bomb with no animations (PB3) | Checked; → C7 | test_pb3_qa, test_pb3_bomb_hands (the rail row, half a metre, BOMB ARMED for either team). |
| 76 | Plant The Bomb's edge cases (PB1) | Checked | test_pb1_qa, test_lifts (a carrier hit mid-jump or mid-ride drops on the floor left), test_bots_plant. The fuse's tension: Held, Plant The Bomb balance. |
| 77 | Stand-in sounds and prop (PB1) | Gone → B1 | His recordings (AU11) and the model (PB2) replaced most; the rest is B1. |
| 78 | Your recordings of 13 Nov (AU11) | → B1 | test_au11_qa holds them; the sound is his. |
| 79 | Stockade (SK1) | Held: map redesign | Dev-only map; layout. |
| 80 | Depot's flags between crate stacks (MB1) | Held: map redesign | test_mb1_layouts. |
| 81 | Woodland's broken sight lines (MB1) | Held: map redesign | |
| 82 | Woodland's 9 s flag (MB3) | Checked; Held: map redesign | test_mb3_raise, test_aud2_ui (the Match page's line). Fair or long is the redesign's. |
| 83 | Woodland's Ridge brow (MB4) | Held: map redesign | test_mb4_brow. |
| 84 | Woodland's Long road (MB2) | Held: map redesign | test_mb2_qa (nothing on the road). |
| 85 | Woodland's flags (MB1) | Held: map redesign | |
| 86 | Subway's flag B (MB1) | Held: map redesign | |
| 87 | Bots in a bush at point blank (BU1) | Checked | test_bu1_point_blank_bush, test_bu1_qa (2.5 m, half a metre of leaf, two foes shoot it out). |
| 88 | The audit's fixes (AUD1) | Checked; → A5, E2 | test_aud1_qa (each of its 13 lines: start stagger, facing, lift legs, set-down, smoke then plant, the rail, callouts off, skip, torch under laser, help text, AZERTY, slider, restore). The Ultra arch and lift reflections → A5. |
| 89 | The audit's second pass (AUD1) | Checked; → A6, C3, E2, Held | test_aud2_* (lockers clank, lift gaps, mags, swinger, rifle over a crate, loading steps, round time drag, bots' arm switch, bolt home, level 10 and 12). Simpler renderer → A6 (and fixed here); balance calls → C3; Report a Bug → E2; bushes and smoke routes: Held, bot routes; Plant The Bomb rate: Held; the Range's props: Held. |
| 90 | Smoke and flash bombs (SF1) | Checked; → C5 | test_grenades, test_sf1_qa; the milky screen → C5. |
| 91 | New Depot, the hall (DR1) | Held: map redesign | |
| 92 | Props (DR2) | Checked; → D1 | test_dr2_qa (no gaps behind racks); the colours are his. |
| 93 | Depot frame rate on Low (DR2) | → A1 | The laptop. |
| 94 | The art direction on Depot (AD1) | Gone | Replaced by Sunlit Concrete (SL1 to SL4, V5): grime and warm sun are now meant, no violet shade. The look → D6. |
| 95 | Graphics that scale (AD1) | Checked; → A1, A2 | test_graphics_table, test_graphics_apply; frame rates are his PCs'. |
| 96 | Click to skip (MC1) | Checked | test_mc1_qa, test_aud2_* (a skipped round gives no XP). The skip's length on his PC is minor; dropped. |
| 97 | Bots' gunfire and ambience (AU1) | Checked; → B2 | test_au1_loudness, test_au1_qa; listening is his. |
| 98 | Full-screen map (FM2) | Checked; → D6 | test_fm2_field_map, test_fm2_qa. |
| 99 | Bug pass BP2 | Checked; → A4, D6 | 13 of 16 by tests (9 Nov); Woodland's reflections and two night matches → A4; the crosshair → D6. |
| 100 | Team sizes (TS1) | Checked; Held: map redesign | test_team_sizes. Fair and fun at each size is the redesign's. |
| 101 | Frame time at 8v8 (TS1) | → A1 | The laptop. |
| 102 | Leans to check (TS1) | Gone | Woodland's attack rate changed with MB3 (9 s raise); the map redesign owns it. |
| 103 | Depot bots and full auto (NA1) | Held: bot aim | test_start_mode_bots. |
| 104 | Bug pass BP6 | Checked; → A2, D4, D5, D6, E2 | 7 of 16 by tests (9 Nov); Customise framing at 1080p by the pictures; the debug views, Woodland's loading and firing over cover were changed by the audit (test_aud2_perf, test_aud2_simb). Scopes → D4, frame rates → A2, bots up close → D5, other screens → E2. |
| 105 | Bug pass BP7 | Checked; → A2, A6, B2, C1, D5, E2 | 8 of 18 by tests (9 Nov). Occlusion and smoke frame time → A2, Lounge light → A3, pad → E2, ambience → B2, icon → E2, bomb pin → C1, mag tosses fair: test_bot_mag_share, dropped as a feel question; loading → A1; bots' torches → D5; hit call patch → D5; Sniper bolt → C1. |
| 106 | Cut-off throw (GT4) | → C1 | test_grenade_throw_qa. |
| 107 | Lasers, the Dev egg (LZ1) | Checked | test_lasers, test_lasers_qa (off plays exactly as never on). Fun or not is a Dev toy's; dropped. |
| 108 | Bug pass BP8 | Checked; → C1, D4, D5, D6, B2 | 11 of 20 by tests (9 Nov); the rail at 720p by its test. Bots sprinting → D5, laser and torch → D4, scope glass → D4, Variable Scope top → D4, flag 7 s → Held map redesign, louder bombs → B2, reloads and grips → C1, icons at 720p → D6. |
| 109 | Mode order (MOD1) | Checked | test_mod1_qa and the Match page picture (Plant The Bomb now third). |
| 110 | Retro filter (RF1) | → A6 | test_rf1_qa; needs his card. |
| 111 | Lightly used replicas (RW1) | Held: replica materials | |
| 112 | Lightly used magazines (RW2) | Held: replica materials | |
| 113 | Subway's lifts (MT2) | Checked; Held: map redesign | test_lifts, test_mt2_qa, test_bot_lifts (calls, riding, doors, buzzer, bots). Worth taking or too slow: the redesign's. |
| 114 | Woodland's far trees (FT1) | → D2 | test_ft1_qa. |
| 115 | Subway in CC0 materials (MT3) | → D3, A1 | The yellow strip and sleepers are gone since (TB1, the track rework); what's left is the look. |
| 116 | Climbing out of the track (CL1) | Checked; → C6 | test_climb_qa, test_bot_climbs, test_pp1_climb_qa (bots never stuck, props vault, never climb). |
| 117 | The shirt collar (CN1) | → D5 | test_figure_collar_skin_qa. |
| 118 | Subway's echo (EC1) | → B2 | test_ec1_shot_echo. |
| 119 | The Pump Shotgun (SH1) | Checked; → C2 | test_pump_shotgun, test_sh1_qa (pattern, pump, shell, one hit for two BBs, level 10, public). |
| 120 | The Pump Shotgun's model (SH2) | → D4 | test_sh2_qa. |

## Decisions

- **The flash is called in words (critic, attempt 1):** a new callout event, Flash out, said by the thrower as it lets
  go, past the bot's and the team's gaps (the bang is 1.5 s off). Bots' look-away stays on the throw, as callouts.md
  says: what a bot says never changes how anyone plays.
- **MQ4's check came in during the pass** (its thread added it to the old list at 06:46); it stands as N1 under New
  checks, in the same words, as it needs the owner's eye in play.
- **Feel questions on a default already taken are dropped** where nothing hangs on them (the Lasers egg, the skip's
  length on his PC, refused magazine tosses): the owner's defaults rule says the default stands; he can raise any.
- **Several old items share one new one** where one sitting covers them (every Woodland model is one walk, D2; every
  frame rate on the laptop is A1).
- **The fix keeps Forward+ as it was:** the copies are made only where `RenderingServer.get_current_rendering_method()`
  is `gl_compatibility`, so the main renderer still shares one material a look and sets the floor per instance.
- **The record lives here, with a pointer in `docs/PLAYTEST.md`,** not in PLAYTEST itself, which is already 144 KB.
