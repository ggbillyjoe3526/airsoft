# BP6 · Fix the remaining known issues and check the UI

**Review:**

- part 1: critic Accept 7/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-07 | part 1: 1 | Opus 5.5 | green | Retry 6/8 | stale comment, no skin check, torch row, long line |
| 2026-11-07 | part 1: 2 | Opus 5.5 | green | Retry 7/8 | the glass cone's edge could pop detail in view |
| 2026-11-07 | part 1: 3 | Opus 5.5 | green | Accept 7/8 | – (two wording fixes made) |

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
