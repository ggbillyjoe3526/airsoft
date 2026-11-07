Task: none · BP6 part 3 (models) · Verdict: Pass
QA, BP6 models, head fbdf498: PASS, no blocking. 18 files, 169/169 (bp6_models, hit_call_arm, hands_on_replica, model_pictures, replica_paint, customise_parts, figure_pads, figure_models, figure_view, figure_view_cone_qa, figure_copies, figure_body, bp5_models, bp5_models_qa, magazine_models, attachment_models, hd2_hit_call_stack, figure_hands).
- Paint: ReplicaPaint only overrides Body/Furniture/Detail/Accent/Metal; Rubber and BB never painted, so the fold changes no paint.
- fold_material: BB faces UV (0.5,0.5), Rubber (0,0), constant per face so mip 0 always; margin only at mip 0 (note).
- Pictures 06 and 08 identical before/after. human_gear_* gone (only a historical mention in BL12.md).
- Hit-call clip: collarbone slerp on the arm's raise share; test checks >=20 deg every 1/30 s. Robot untouched.
- _camera_cut sound. Imports present (pads col BC7).
Minor: stacked doc comment at figure_view.gd ~523 (_seen has none); "material is null" lines twice in the combined run (pre-existing on main per graphics critic).
RETRY (head 40d954c, rebased on #241's branch): PASS. 20 files 167/167 (adds bp6_graphics, bp6_bots, figure_animator, figure_pose, figure_mix, hd2_hit_call_stack, figure_hit_area, hit_fit). Weights changed on all three Body levels (LOD0 2484, LOD1 246, LOD2 76 vertices; counts identical); tests check LOD0 only (advisory). No HitFit/HitPose/sim change; hit tests pass. Robot untouched; call.py and clips as base. human.glb 8 materials (Gear folded into Pads); BodyMerge still merges. No leftover references; run order pads.py before gear.py.
