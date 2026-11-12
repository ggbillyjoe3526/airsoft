Task: MQ1 · Replicas made of steel, aluminium and polymer
Attempt: 2 of 4
Head: f0298f3 (checks passed on it; it is `git rev-parse HEAD`. The performance report was written on 6029fe9, and only test_mq1_qa.gd and the two reports changed after it.)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✓
Score: 8/8 → Accept

Failed checks, with evidence: none.

Basis for each check:
1. I judged the models from renders 01 to 06. The record names no reference photos, so proportions are checked BEFORE against AFTER. The silhouettes are identical: AEG length 738/740 px, handguard, magazine drop, stock and slide all within 1 %, and the poses are unchanged.
   - Attempt-1 must-fixes, all met:
     - Black metal is the darkest part, with a satin highlight. This is visible on the GBB Black slide, the SMG magazine and the sniper barrel.
     - The Ghost slide is off-white satin, not silver, and no grain smears over the serrations (replica_surfaces.gd:+44 sets stretch 1 on steel).
     - The sniper barrel and its thread cap are dark steel in Tan (sniper.py:+552, +565).
     - The polymer tones are the owner's (polymer gain 0.72 with bold_keeps 1, replica_surfaces.gd:+40-41).
   - The owner called these renders "Excellent" (15:34).
2. No contract changed. CC0_ASSETS › Surfaces is updated to the 16 slots.
3. No per-frame allocation. dress() sets four prebuilt tables once per material (replica_surfaces.gd:+107-110). The shader adds ALU work and no texture fetches (replica_surface.gdshaderinc:+116-123).
4. test_metal_keeps_a_light_paints_colour_and_only_bare_metal_is_brushed (test_replica_surfaces.gd:+109) fails without the attempt-2 change: there was no `light_keeps`, `floor` or `kind_shine`, and steel had stretch 10.
5. Shader constants are named (LIGHT_PAINT, LUMA, CHROMA_FLOOR, gdshaderinc:+63-66). The presentation is only shaders and materials, and every variable is statically typed.
6. Coated satin steel, matte polymer and no markings fit "toys, not firearms". Bots keep flat paints.
7. The renames are complete (`_surfaced`, `MAX_SURFACED`, `surface_materials`), OWN_GLOW is gone, z_clip_scale now sits before the tables, and the Lossless import has a written reason.
8. The scope is MQ1: wood is used by no replica, as the owner ruled. DECISIONS, the wiki and the record are updated. The changelog note is still due at pipeline step 6, after the critic.

Advisories (not blocking):
- game/play/replica_wear.gdshader is dead code now. Add it to KNOWN_ISSUES or to the owner's sweep list so it isn't lost.
- AEG rail tops (render 01, the Cobalt pair) catch the overhead box as a white and black checker. It is physically plausible, but at hip it could read as aliasing.
- Renders 03 and 06 of the Compact SMG show only the hands' copy. A bot's copy is still flat by design.

Must-fix for the next attempt: none.

Owner should test in the game (Forward+, on a GPU):
1. GBB Pistol in its default paint, hip and inspect in the Depot: does the slide stay in the paint's colour, or go grey as it did in the Compatibility render 06?
2. AEG Rifle at hip in Cobalt: do the rail teeth shimmer or crawl as you move?
3. Black replicas under the Subway's dim light: is black metal still darker than black polymer but never pure black?
4. Customise pictures and turntable: do the soft studio panels give believable streaks on rails and barrels?
5. Cyber Pistol: does the white coated shell's fine grain look like a finish or like noise up close?
6. First equip of each replica on the Low preset: any hitch, and is the frame time fine with the grain fetches?
