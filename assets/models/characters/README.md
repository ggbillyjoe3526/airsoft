# Character models

- `human.glb`, `robot.glb` and their sidecars `human.json`, `robot.json`: the rigged Blender figures (BF1), made with
  `tools/blender/bot-figure/` and approved by the owner on 2026-10-12 (the human redesigned in RM9, approved
  2026-10-13; the robot in RM10), kept here unpacked (the browser game packed them with meshopt, which Godot can't
  read). Each has a 65-bone skeleton, 32 clips (moving, aiming, reloads, the switch, the hit call, the walk-off, resting
  on cover, the vault, holstering), LOD1 and LOD2 meshes as separate nodes, and the human four heads, one per figure;
  `docs/KNOWN_ISSUES.md` says what the figure code must do about those. The sidecar gives the clips' lengths and paces,
  where each replica sits on the `Grip_R` bone and where the magazines go in the reloads. How the browser game drew
  them: `legacy/browser/src/config/figureRig.ts`.
- The human's four heads (`Head_HighCut`, `Head_Cap`, `Head_Boonie`, `Head_FullCut` and their LODs) are rebuilt from
  the owner's photos by `tools/blender/figures/` (BL11), which splices them into `human.glb` with their own atlas
  (`human_headwear_*`); the rest of the figure is left alone.
- The human's `Body` (its clothes, gloves and boots, with `Body_LOD1` and `Body_LOD2`) is rebuilt by
  `tools/blender/figures/body.py` (BL10) and spliced in by node, leaving the skeleton, the clips and the other parts
  alone: `BODY_MAPS=<dir> python -I tools/blender/figures/body.py <repo> out.blend body.glb`, then the splicer
  replaces `Body` (and `Kit_Pads`) in `human.glb`. The build reads `human.glb` itself, so build into a copy and splice
  afterwards. The heads (`Head_*`), the carrier and gear (`Kit`, `Kit_Pack`, `Kit_Radio`) and the knee pads
  (`Kit_Pads`) are separate nodes, each owned by its own build.
- The human's knee and elbow pads (`Kit_Pads` and its two LODs, BL13) are a part built by
  `tools/blender/figures/pads.py` and spliced into `human.glb`; they ride the shins and forearms rigidly.
- Godot extracted each figure's textures beside it on import (`*_col`, `*_nrm`, `*_orm`); commit them with their
  `.import` files.
- A CC0 figure can replace them later: node names, team colours, scale, the size budget and where to find CC0
  models are in [docs/CC0_ASSETS.md](../../../docs/CC0_ASSETS.md).

Record every model in [docs/ASSETS.md](../../../docs/ASSETS.md).
