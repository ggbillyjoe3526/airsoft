# QA report: SL4 menus, HUD and replicas (HEAD 64813e3)

Verdict: FAIL on 64813e3 (one test file not updated); fixed in the next commit.

Blocking
1. tests/unit/test_lo3_qa.gd still compared the painted material to the raw scheme colour (4 of 7 failing). Fix: the
   expected values go through ReplicaPaint.drawn(), as in test_replica_paint and test_loadout_screen. Fixed: 7/7 pass.

Checked and fine
- test_replica_paint 14/14 (with the new saturation and matte test); test_ur7_qa, test_ac1_qa, test_colour_vision,
  test_accessibility_table pass.
- ProjectSettings read: project.godot carries look_paint_saturation as {type, value} 0.6; exports bake project settings;
  fallback 1.0; the new test pins it to LookConfig.paint_saturation.
- Cache keyed by paint; drawn() once per set; the value is constant at runtime (push_globals writes RenderingServer only).
- Cyber Pistol: own colours skip the five parts; only its realistic grey goes through drawn().
- Swatches drawn as painted; no leftover old hexes in game/ or tests/.

Non-blocking
- replica_pictures.gd _restyle paints power-source labels with PowerModels' colours, not schemes (traced: unaffected).
- ACCENT d8ccb2 vs TEXT f2eee6 is about 1.3:1, so accent words beside white words are a soft distinction: owner check.
- Focus rings on accent-filled controls stay as invisible as with teal (no regression); hovered accent is near TEXT.
