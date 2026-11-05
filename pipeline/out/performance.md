Task: MP1 · head 44a75b9 · Verdict: Pass
Run: none (read-only review of the diff; nothing measured) · budget: judged against the targets

Blocking findings: none.

Checked and clear:
- HUD per-frame cost: none added. The picture is taken only on entering the tree or a kind change; ReplicaPanel.refresh
  sets only the size and modulate; ReplicaPictures has no _process; _draw is one draw_texture_rect, on redraw only.
  The viewport is UPDATE_ONCE.
- Lifetime: the ReplicaPictures node is the glyph's child, its viewport, model, camera, light and environment its
  children, all freed with the glyph; the material duplicates are surface overrides inside it; created once per glyph.
- Kind changes: the pictures are cached by kind, so at most two viewports per glyph.
- Allocations: one formatted string and a ResourceLoader.exists per take, never per frame.
- The power pictures' refactor into _make_model keeps their behaviour.
- Size: 64-256 px textures, negligible.

Advisory:
1. Each glyph owns its own viewport (HUD and Loadout pay separately); share one owner if more icons appear.
2. The picture's size is fixed when first taken; the 2x supersample covers the HUD's held-bomb growth.
3. No shader prewarm for the picture's materials: a possible one-frame hitch when the first glyph appears, as with
   the power pictures. Check on real hardware that the HUD is built before the round starts.
