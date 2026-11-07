# BP6 · Fix the remaining known issues and check the UI

**Review:**

- part 1: critic Accept 7/8 · qa Pass · performance Pass
- part 2: critic Accept 7/8 · qa Pass · performance Pass
- part 3: critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-07 | part 1: 1 | Opus 5.5 | green | Retry 6/8 | stale comment, no skin check, torch row, long line |
| 2026-11-07 | part 1: 2 | Opus 5.5 | green | Retry 7/8 | the glass cone's edge could pop detail in view |
| 2026-11-07 | part 1: 3 | Opus 5.5 | green | Accept 7/8 | – (two wording fixes made) |
| 2026-11-07 | part 2: 1 | Opus 5.5 | green | Retry 5/8 | Hold Here on the map, lane resume, MI1 unproven, zoom keys |
| 2026-11-07 | part 2: 2 | Opus 5.5 | green | Accept 7/8 | – (the flaky test logged, a record line fixed) |
| 2026-11-07 | part 3: 1 | Opus 5.5 | green | Retry 5/8 | collarbone drop backwards, glove clipping, GBB nose, docs |
| 2026-11-07 | part 3: 2 | Opus 5.5 | green | Retry 6/8 | a cloth flap under the raised arm, a changelog claim |
| 2026-11-07 | part 3: 3 | Opus 5.5 | green | Accept 8/8 | – |

## The pass

Asked by the owner on 2026-11-06, after BP5: fix as many of the remaining `docs/KNOWN_ISSUES.md` rows as can be fixed,
and check the game's UI, menus, images, icons, text, animations and asset loading for bugs. Rows that need his play
(class playtest), his OK (the first-person arms), a model call or a limit kept on purpose (class document) stay.

Workers took one area each in their own worktree (play and bots, menus and HUD, graphics and maps, models), and two
UI readers screenshot every screen under Xvfb at 720p, 1080p and 4K (`/mnt/project-files/playtest/bp6/ui-audit/`).
Each area goes out as its own pull request with the critic, QA and performance agents.

### Part 1: graphics, performance and maps

#### Detail lines and a scope's zoom
- **Goal.** A figure seen through a scope is drawn in the detail of how near it looks. A part with no far level (the
  radio) no longer vanishes.
- **Approach.**
  - `FigureConfig.zoomed_lines` scales the lines by a zoom.
  - `FirstPersonView.detail_zoom` is the most the eye magnifies with the sight up at all (aim > 0): the view's aim
    zoom, or a scope glass's turned zoom (`glass_zoom_of`). It takes the target, never the eased value.
  - `PlaySession._set_figure_lines` gives every figure those lines when the zoom or the preset changes.
  - **Tried and dropped: a glass cone.** Retry 1 scaled only figures inside a cone round the view axis, as wide as the
    unzoomed view over the glass zoom. The critic dropped it. The cone wasn't taken from OpticGlass's own camera, so
    its edge could pop a figure's level in view, and in the bench it cut almost nothing (8 of 11 bots inside). Every
    figure takes the zoomed lines again; the cost is a KNOWN_ISSUES row.
  - A part's coarsest level draws to every distance, so the radio's LOD1 stays past the far line.
- **Default (iron sights).** The view's aim zoom (1.2 on iron sights, an optic's own) scales the lines too. The whole
  view is magnified then, so a figure keeps the detail its size on screen asks for.
- **Risks.** Lines change only at a raise or a zoom turn, so no frame does extra work. While a zoomed glass is up,
  every figure within the zoomed lines poses and draws at full detail (see the scoped bench).

#### Bodies in fewer draws
- **Goal.** Fewer draws a level for the same pixels.
- **Approach.** `BodyMerge` folds each level's opaque parts on the body's own skin into one surface a material. It
  copies ArrayMesh's private `_surfaces` bytes: positions as one stream, then normals and tangents; attributes and skin
  per vertex. It offsets the 16-bit indices. Its mesh LODs are every part's edge lengths, each holding the coarsest LOD
  a part has at or under it, so the engine picks per part what it picked before.
- **Kept unfolded.**
  - A part with a see-through surface keeps its own draw, so its depth sort is unchanged. That is every human head:
    the Lens. The four heads therefore share one merged mesh a level; meshes are keyed by kind, level and source meshes.
  - While a figure fades, its parts draw instead of the merged mesh, each sorted by its own depth.
  - A part on another skin keeps its own draw.
- **Draws a level.** Human 11 to 9 (Kit, pack and radio share Gear), robot 13 to 7.
- **Shadow twin.** Hidden while no light casts shadows (Sun shadows off; the torch's shadows need the sun too).
- **The `_surfaces` dependency.** `test_bp6_graphics` pins it on 4.7.2. Every merged array read back equals the parts'.
  The LOD the engine would pick is compared at 10 thresholds. A new engine must pass these tests first.
- **Pictures.** Compatibility under Xvfb against main: pixel-identical at 4 and 20 m for both kinds and at 40 m for
  the robot. The human at 40 m differs by 644 px, the radio now drawn. Pictures are in
  `/mnt/project-files/playtest/bp6/graphics/` (body-merge before and after, the radio crop, 6x scope side by sides).
- **Totals** in those pictures, sun shadows on: human 34 to 32, robot 27 to 21.
- **Memory.** The merged meshes are 6 meshes holding 5,796,912 bytes (vertices, attributes, skin, indices and LODs).
  They were 15 meshes when cached a head. The parts stay loaded for the fade.
- **figure_bench (headless, 11 figures).** set_body went from 191.7 ms to 201.6 ms (the critic's runs; one 277.7 ms
  outlier). The merges are made once a session, behind the loading screen. Animation plus skeleton is inside noise
  (2.35 ms against main's 2.56 ms, eye in the middle).
- **Scoped bench (eye at the Alpha spawn, `--far --zoom N`).**
  - At 1x: 0.84 and 0.88 ms.
  - At 6x: 2.41 and 2.31 ms, about +1.5 ms with the eye at the spawn and the bots past the unzoomed far line. With
    the eye mid-field and the bots already within it there is no cost (2.48 against 2.39 ms, the performance rerun).
    Every figure is then inside the far line, so all are posed every frame, as with the eye among them.
  - The dropped cone gave 2.33 and 2.21 ms.
  - GPU skinning and vertex cost at LOD0 are unmeasured (no GPU). New KNOWN_ISSUES Performance row (can wait): a cone
    from OpticGlass's own camera, its edge hidden behind the disc, could cut it.

#### Depot doors 5 and 8
- **Approach.** `DoorView.reach` steps a leaf back from flat (half a turn) in 0.005 rad steps until no point of it is
  inside a block. This is visual only: an open door has no collider.
- **Result.** Leaves 10 and 16 (door 5 and door 8, leaf 0) reach 2.6416 rad. Every other leaf is still exactly PI,
  kept in a PackedFloat64Array.

#### Rows
- **Removed.** Graphics "Figures change detail by their real distance"; Performance "The detail lines ... don't scale";
  Performance "A figure's body draws 11 parts"; Maps "Depot's doors 5 and 8".
- **Added.** Performance: while a zoomed glass is up, every figure within the zoomed lines poses at full detail.
- **Changed.**
  - The weapon torch row. Bots get the light by rule, not as a fitted part, so no model shows. Fitted, its three own
    materials add 3 draws a replica at any range, 6 for a bot's two (AEG and pistol).
  - The occlusion row now notes it is unmeasured here.
- **Left, with reasons.**
  - **Occlusion culling.** Compatibility does none, and there is no GPU.
  - **Woodland's load freeze and nav grid.** They are game/nav and game/ai, the bot worker's code; the grid change also
    changes routes.
  - **Moon shadows.** A 50 m night range overrides the Shadow range setting; needs a GPU.
  - **Drum collision.** Boxes throughout (blocks, BoxWorld matching Jolt, the nav raster), and that is sim code.
  - **Contact shadow on ramps.** It needs a ground ray a figure a frame on Low.
  - **HitPose rows.** HitPose is simulation code.
  - **AEG parts file size.** It needs a Blender re-export, and one is under way.

#### Tests and checks
- `tests/unit/test_bp6_graphics.gd`: 10 tests (merge bytes and LODs, fade swap, paint, skin, shared heads, the
  zoomed lines and the glass zoom, twin, doors). `tests/unit/test_figure_body.gd` is updated for the radio.
- The "material is null" lines in the test output are there on main too.
- check.sh was stopped at its 1 h limit, three runs sharing the machine. Results:
  - Part 1 stopped in test_dev_play with 0 failures logged. Run alone, it passes 10/10 and test_dev_settings 16/16.
  - Parts 2, 3 and 4: 790, 1677 and 1354, all passing.
  - The smoke test passes. The licence notices were generated without error.

#### For the owner to test (needs a GPU)
- Through the Variable Scope at 2x to 6x: no visible detail pop at the raise or as the zoom turns.
- A walk-off fade: no flicker as the merged mesh hands over to the parts.
- Frame time on Low and High with 5v5 to 8v8, scoped and not.
- On Ultra, the merged bodies under SDFGI and SSAO look as before.

### Part 2: play and bots

#### What changed

- **Zoom keys of their own.** Zoom in and Zoom out are actions (Settings › Controls), on the wheel by default with
  Next and Previous replica; the one sharing allowed (`KeyBindings.may_share`), any other key swaps. Aimed through
  the Variable Scope a shared key zooms only. The zoom decision is read before the tick (`Aiming.zoom_turns`), so a
  notch on the tick a reload or draw starts switches.
- **Hold Here's key on the open map** is a Hold Here at the pointer (`PlayerCommand.ping_hold`, a PING with value2
  `PING_HOLD`, `SquadOrderBook.give_hold_at`), held until the order ends.
- **Bombs** bounce off the bodies of those in play (surface NONE, never resting on one; `Grenades._body_hit`), and
  pass through the thrower's team for `team_pass_time` (0.3 s), so one thrown past a teammate at the thrower's side
  doesn't bounce back onto the thrower (without it the test's bomb landed 1.6 m behind the thrower).
- **A ping** looks through glass as sight does (`sight_ray`).
- **The bolt's cocking sound** stops on a switch, a holster or leaving play (`SimAudio._cut_bolts`, VoicePool
  serials); its lists are sized at setup.
- **A BB's second impact in a tight inside corner** in view is heard open (`SoundOcclusion.impact_share`,
  `occlusion_corner_reach`, `occlusion_impact_skin`).
- **The flash's flare** runs down at most 1/30 s a frame, so a hitch at the bang still shows it.
- **The minimap** draws a patch heard on another storey at `other_storey_patch` (0.5) strength.
- **End the round now** in Elimination's overtime keeps the flag's time played (`OvertimeFlag.cut`).
- **The menus' picture and turntable cameras** are never physics-interpolated (the flaky UF1 camera test).
- **HitFit's lower body tables** are made when a Simulation is made (`HitFit.prepare`), keyed by `HitFit.Lower` so
  every table a pose asks for is one prepare makes.
- **Bots:** full auto indoors decided once per target a round (bitmasks) and re-checked when a held burst resumes;
  keep_apart skips an enemy behind something solid (`separation_line_height`); back from a search a bot resumes past
  the lane segment nearest it (`BotMovement.resume_point`); a fresh semi or burst pull waits until the replica, and a
  vault's fire lockout, let it fire that tick (`BotCombat.press_kept`); a real noise by a pinged spot is news; Go
  round's spot is on a floor a route joins (`NavGrid.linked`).

#### Rows fixed and deleted

The bolt sound; the wheel notch as a reload or draw starts; NA1's two targets and its held burst; the zoom on Next and
Previous; the ping through glass; the UF1 camera test; the BB's second impact in a corner; the search walk-back; Go
round's spot; the real noise after a ping; the order keys on the full-screen map; press_buffer; keep_apart;
`Simulation.step` allocations (MI1); the flare after a hitch; End the round now; the minimap's heard patch. Trimmed:
the seed row (`--seed` is refused, test_launch_seed) and the thrown bomb row (its arms part left).

**MI1's evidence.** Its own scenario (Depot, Normal, seed 9, player 0 not driven, every allocating `Simulation.step`
after 5 s, events not counted, 150 s, each run alone in a fresh process): main cf1705d makes one object at 11.02 s, a
HitFit table made the first time a pose needs it; the head makes none. Both make about 90 on the match's first shot
(10.82 s), the hit volumes growing once (`BBStep`), the warm-up test_bb_step names, so no row. The row's own times
(48.9 s, 56.0 s) were from an older build.

#### Rows left

- Follow me can't close on a sprinting leader: a lead ruling (DP4); a fix needs followers faster than the player.
- An ask to a bot already bringing a magazine: design, HUD and art items (MH2, MH3), mostly others' areas.
- The one-way step region: no failed search ever measured; directional regions over the 528k-node grid are a nav
  build refactor.
- BotAngles and bushes: a per-ray leaf test across Woodland is a frame-time risk and moves Hard bots' Woodland play.
- The figure's muzzle up at a wall: figure_view.gd is the graphics worker's, and it is an art call.
- The pacer above 100 % game speed: needs a second past tick kept across every view.
- Leaving a match while it loads: menus (main.gd), the menus worker's.
- The thrown bomb from the eyes, keeping its pin: the arms, out of bounds for this pass.

#### Defaults

- The zooms default to the wheel with the switches: the feel on default keys is unchanged.
- Only a zoom and a switch share a key: the swap rule stands for every other key (DECISIONS › Zoom on the wheel).
- Hold Here on the map holds the pointer's spot, looking on the way there: the hidden view can't be read
  (DECISIONS).
- Bombs bounce off in-play bodies only: one out of play has walked off and can't be in the way.
- The thrower's team passes for 0.3 s (about 4 m of throw): far enough for a teammate at the side, short enough that
  a teammate down the hall still stops it.
- keep_apart checks a clear line for enemies only: teammates push a few cm, wall or none, as before.
- Go round's spot is checked by nav region, not route length: linked is cheap, and while it doesn't promise a
  route it never marks a floor no route joins to yours.
- Other-storey patches at 0.5: seen, yet plainly not your floor.
- The torch going off for a throw stays: by design (the hand holds the bomb).

#### Checks

Touched tests green (test_bp6_bots, test_fm1_go_there, test_fm1_field_map, test_key_bindings, test_mc1_qa,
test_sf1_qa, test_variable_scope, test_grenades, test_sniper_rifle, test_hit_fit, test_bp2_perf_qa, test_hitbox,
test_bp3_qa, test_start_mode_bots and others). Attempt 1's whole check.sh: 3,945 of 3,946 passed; the one failure,
test_parts_in_play's silenced shot, passes alone (a headless voice that finished between two ticks under load). Depot
match guard: 121 rounds over 16 seeds, 0 on time at attempt 1; 118, 0 on time and 1 to the overtime flag at attempt 2
(the lane resume and the vault gate; earlier baselines 129 and 121).

### Part 3: models

Rows of docs/KNOWN_ISSUES.md this part took, after the critic's retry (attempt 2). Pictures:
`/mnt/project-files/playtest/bp6/models/` (01-12, each labelled: model, bot figure or first-person replica, view, what
changed, where to look; 07 and 08 one sheet each for the AEG and the Sniper Rifle). 12 is new: the owner's locked-back
photo beside our render from its angle.

#### Hit call shoulder (row deleted)
- **Goal:** no dark shirt flap between the helmet and the raised arm in the hit call and walk off.
- **Approach:** the root fault was weights, not the clip: the chest's side under each arm (rest y 1.17-1.30 m, about
  11 cm from the upper arm's line) was weighted 70-98 % to the upper arm, so it swung up over the carrier's strap.
  `tools/blender/figures/body_weights.py` (new, numpy, in place) gives up the upper arm's share on the arm's inner
  side from 5 cm of its line (the sleeve) to all of it at 11 cm, near the shoulder (eased out 30-55 % down the arm;
  past 13 cm at any point), every factor eased (the inner side, the distance, the start at the joint) and the share
  given up averaged 12 times over neighbouring points; it goes to the point's other bones or to Chest/Spine1. It
  changes both arms on all three Body levels; the tests below check LOD0's strap and all three levels' weight steps,
  and the pictures are LOD0.
- **Attempt 2's flap (critic):** its fade ran over only 2.6 cm (6.4 to 9 cm) with a hard inner-side cut, so the cloth
  folded where the share ran out: a pointed flap with stepped edges hung under the raised arm (sheet 01, the old
  close-up; a step in sheet 02's front view). Now the arm's underside curves into the chest in one line (sheets 01-03
  re-rendered, 01 with a side view of the armpit). What remains: with the arm straight up the armpit is a smooth
  web of shirt from the arm to the chest's side, a soft bulge in the quarter view (sheet 02, bottom), not a fold; the
  reload clip and others not in the picture tool were not looked at.
- **Collarbone:** the first attempt's 24 degree drop is reverted: `gait/call.py` and the HitCall/WalkOff clips are
  main's. The strap buckle sits straight and the shoulder's cap keeps its weights.
- **Tests:** test_hit_call_arm `test_with_the_arm_up_the_shirt_stays_under_the_shoulder_strap` skins Body and Kit in
  software every 0.1 s of both clips and counts shirt points ahead of the strap's front: 0 (5-23 on main).
  test_bp6_models `test_the_chest_s_side_eases_off_the_upper_arms_with_no_step`: on every level and both arms no edge
  by the armpit changes the upper arm's weight by more than 0.25 / 0.35 / 0.45 (LOD0/1/2); attempt 2's weights failed
  it at 0.77-0.92.

#### Glove knuckle shards (row narrowed)
- **Goal:** plates stay whole when a finger bends round a grip.
- **Approach:** body_weights.py finds the 28 plates (14 a glove: back plate, its border, four knuckle domes, eight
  finger guards; shells of the LOD0 Body of at most 300 points all led by a hand bone, a tie counting as the arm's)
  and puts each on one weight set: the bone it leans on most, a dome (under 70 points) its top two bones' mean so it
  turns part way with the finger. Cloth within 2.5 mm of a plate takes its weights, fading out by 6 mm; other small
  shells (the wrist strap tab) are skipped. LOD1/LOD2 have no separate plates.
- **What remains (the row now):** a few cloth slivers past the back plate's top edge and a small dark gap by a dome at a
  deep bend; closing them needs inset plate borders or a split dome in body.py (a full body rebuild).
- **Rebuild order:** body.py splice -> pads.py -> gear.py -> body_weights.py last. A splice brings back the blended
  weights; the script marks the Body's mesh (extras BP6_WEIGHTS), which a splice replaces, so a rerun after a splice
  is not skipped. Written in body.py's docstring, the figures README and the script.
- **Test:** test_bp6_models `test_each_glove_plate_moves_whole` (every plate's points share one weight set; 28 plates).

#### Material budget (row narrowed to the pistol)
- AEG and Sniper Rifle 7 -> 6 (Rubber and BB folded into one material on a 4x4 px swatch, hardsurface.py
  `fold_material`), the figure 9 -> 8 (the gear's swatches painted into the pads' maps). The GBB Pistol stays at 7:
  its unpainted pair, the grip's tiling stipple normal map and the BB, can't share one texture without the stipple
  tiling over the BB. Test: test_bp6_models `test_every_model_is_within_the_material_budget`.
- **File growth:** the fold adds a UV layer to every Rubber/BB mesh (AEG +259 KB, Sniper +243 KB on disk). Kept: a
  vertex colour would be smaller but carries only the albedo, not the BB's own roughness and metal (the swatch's
  ORM), so it would not keep the look exactly (critic's optional point 6).
- **VRAM:** `human_pads_col` imports as BC7 (BC1 darkened the gear's flat swatches): +175 KB VRAM.

#### GBB dust cover (row kept, reworded)
- **Goal:** the locked-back front as the owner's photo 83c82df7: walls up to the barrel, one rounded front (~0.3
  barrel widths at the top edge).
- **Approach:** BP6 rounded the nose (top corners from above, the foot curving into the face, the lip channel's floor).
  Triangles in the hands 39,250 -> 39,590 (+340, Body 29,064 -> 29,404; budget 40,000); figure copy 3,000 (Figure
  2,760 + Figure_Magazine 240), unchanged. Sight picture untouched.
- **Not done, plainly:** retried on the retry and rendered from the photo's angle (sheet 12). The frame's walls stop
  4.2 mm (0.3 barrel widths: frame top py 110, barrel bottom py 97.7) under the barrel because the slide's solid lower
  front sits there in battery; raising them means grooves in the slide's underside beside the barrel (only 1.5 mm of
  room between the lip channel at 7.3 mm and the chamfered nose at 8.8 mm a side) or a higher slide foot, which
  changes the side view the owner matched from his second photo. A recoil spring in the open channel was weighed and
  dropped: a real one sits behind the slide's front wall, so it would not be in his photo. Kept as a known gap.
- **Risk:** none new; pistol.glb and the parts files are unchanged since attempt 1 (no replica rebuild in the retry, so
  figure_parts.py had nothing to remake).

#### Sights: left as is (brief). Sleeve/cuff: left; the fix is a full body rebuild (row says so).

#### Hand settling on a camera cut (row deleted)
- figure_view.gd `_camera_cut`: the hold is re-checked at once when the camera is another one, moved more than
  `hold_view_radius` or turned more than `hold_view_turn` (2 degrees, FigureConfig) since the last check, not only
  every 4th frame. `_seen` notes the camera's place and facing, so while the camera keeps turning faster than 2
  degrees a frame every figure re-checks each frame (cheap: a cone test). Test: test_hands_on_replica's camera-cut test.

#### Tests and gates
- Rebased on origin/claude/project-thread-d2dpfd (PR #241, on main with #240's BodyMerge): no conflicts (only
  docs/KNOWN_ISSUES.md touched by both, merged cleanly). After it: test_bp6_models, test_hit_call_arm,
  test_hands_on_replica, test_model_pictures, test_replica_paint, test_bp6_graphics, test_figure_body,
  test_figure_view, test_figure_models, test_figure_pads: 87/87 (10 scripts, with the armpit test) after one
  fix: #240's test_bp6_graphics expected the
  human to draw 9 surfaces near and far; with the gear in the pads' maps it draws 8, so the test now expects 8.
  gdlint, changelog notes, wiki: pass.
- test_replica_paint's "keeps its own" test checks the AEG's Rubber exists (BB is folded into it); its helper
  `_has_part` has its own doc comment, `_override` keeps its.

#### Rows deleted vs narrowed
- Deleted: the hit call shoulder, the hold settling on a camera cut. Narrowed: the glove plates (to the cloth slivers
  and the dark gap by a dome), the material budget (to the GBB Pistol's 7). Reworded: the GBB dust cover. Sleeve/cuff
  row: notes it waits for the body's next rebuild.

#### The critic's attempt-1 points and how each was met
1. Shoulder: the collarbone drop reverted; fixed at the root in the body's weights; the strap test checks the shirt
   against the strap, not an angle; attempt 2's flap then cleared by the eased, smoothed fade (above).
2. Gloves: plates on one weight set each, domes part way, the cloth under a plate pinned to it; the slivers and the
   dark gap that remain are the narrowed row.
3. GBB dust cover: retried, rendered from the photo's angle (sheet 12); not done, the row says why.
4. Code: figure_view's doc comments un-stacked; float weights asserted, normalised integers scaled on read; the
   rebuild chain written in body.py, the figures README and the script; test_replica_paint checks the folded Rubber.
5. Docs: ASSETS.md figure copy 3,000 (2,760 + 240), "4x4 px swatch", GBB 39,250 -> 39,590; the materials bullet
   dropped; 120-column wrap.
6. Pictures: every changed sheet re-rendered, 12 added, none stale.
7. This record.

#### For the owner to test
- Hit call and walk off from the front, the side and close up: no shirt over the strap, no flap under the raised arm;
  whether the armpit's web reads as cloth. Also a bot reloading and aiming close up (not in the pictures).
- Bots holding replicas close up (spectate, scope): plates whole; the cloth slivers that remain are the known row.
- Spectate cuts and fast turns past a bot: hands on the replica from the first frame.
- AEG, Sniper Rifle and bots' gear: look unchanged.
- GBB Pistol locked back next to his photo (sheet 12): whether the gap under the barrel is worth re-cutting the slide.
