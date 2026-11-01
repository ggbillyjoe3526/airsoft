Task: FM2 (a more detailed full-screen map) · head 0dc04a8 · Verdict: Pass
Run: headless microbenchmarks of MinimapField.build and FieldMapMarks.lay_out on scratch `git archive` copies of 0dc04a8 and 7ed6d93, 7 alternating rounds of best-of-3 builds; 4-core container shared with a running check, so single runs swing +-15 % (main's own Woodland ranged 263-355 ms); no bot match (HUD-only change) · budget: no baseline yet (pipeline/perf-budget.json absent), judged against the DECISIONS targets and 7ed6d93
Metrics (head / main, median of 7): Woodland build ~347 / ~335 ms (about +4 %, under the 10 % line; head 338-382, main 263-355) · Street ~113 / ~114 ms (same) · Depot ~21 / ~21 ms (same) · layer bytes identical to before the change on Woodland and Street, so the terrain no longer adds a full-size resize or blit (earlier heads: +130 %, then +17 %) · lay_out of all words 0.11 ms Woodland (21 words), 0.42 Street (37), 0.36 Depot (31), layout-time only (the new `placed + blocked` copy per word is the extra) · script errors 0
Regressions (> 10 % worse): none (measured).
Blocking findings: none.
Advisory:
- game/ui/hud_minimap.gd View._draw (judgment): the ground texture is one more draw_texture_rect, in a different texture from the layer, so about one more draw call per panel frame (the minimap, plus the full map while M is held); no allocation, a GPU fill of the layer's rect with a 176 x 120 mipmapped texture. Negligible. Only maps with terrain (Woodland) pay it. Draw calls cannot be counted here (no GPU).
- hud_minimap.gd ground_of (judgment): generate_mipmaps and ImageTexture are made once per match; the Image (about 85 KB plus mips) and the texture live as long as the minimap and are freed with it. The default 2D texture filter must be linear-with-mipmaps for the mips to count; without it the draw is plain linear, still fine.
- field_map_overlay.gd (judgment, unchanged): every pointer move re-records all words; likely under 1 ms. A static child Control would avoid it. Optional.
- First M press rasterises outline glyphs for three fonts (judgment, optional prewarm).
Checked and fine: the per-frame paths (View._draw, update, place, set_round, set_teams) allocate nothing new; zone words, first_clear and the Vector2 gap run at layout time only; the settings page's thumbnail View.setup keeps its default null ground; no leaked nodes, resources or double connections; no new material or particle (no prewarm entry).
Fixes: none required.
Unexplained: none. Frame times and draw calls not measurable here (no GPU).
