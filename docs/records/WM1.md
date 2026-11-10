# WM1 · Wear marks: oil stains, tyre tracks and boot prints on the floors

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | see Checks | pending | – |

## Goal

Step 4 of the owner's Ultra graphics (2026-11-09, `docs/ROADMAP.md`), its second half: wear decals (oil stains,
footprints, tyre marks) that add to Sunlit Concrete's procedural wear (SL1, SL2) without repeating it, every map that
names them, scaling per preset.

## Approach

- **Data:** a map's `dressing.marks` (`WearMark`): oil, tyres or boots, at x, z (y, or the ground's height), a heading,
  a length and a bend, muddy or not. Written by the map builders (`tools/depot/build_map.py`,
  `tools/woodland/build_map.py`), each placed on open floor (checked against the blocks).
- **Drawing:** `WearMarks` (built with the bushes in the dressing's staged parts): a Godot `Decal` per stain, per
  wheel per straight piece of a pair of tracks (2 m), per boot print, its box half a metre tall, faces leaning past
  half from the floor faded out, distance-faded from 40 m. Colours from the look's palette (a new `oil`, `rubber`,
  `umber` for dust, `mud_wet`), strengths and shapes in `MarksConfig` (PlayTuning.marks).
- **Pictures:** `WearMarkArt` paints them once at load from noise, with mipmaps (without, a print a few metres off
  faded to nothing): a ragged stain with splashes, darker and shinier (its ORM's roughness) in the middle; one wheel's
  slanted-lug tread whose top and bottom meet, so pieces join; a left boot's print and its mirror.
- **Graphics row** Wear marks, off on Low, on from Medium (Forward+ and Mobile: Compatibility draws no decals), under
  Light and detail, set by `GraphicsApply.apply_field`.
- **Placed:** Depot 16 (8 oil, 4 tracks: Loading bay, Garage, the hall's forklift lanes; 4 dusty trails), 87 decals;
  Woodland 7 (the pickup's muddy tracks up the road, an oil drip by it, 5 muddy trails out of the mud puddles).

## Defaults taken

- Medium and up: decals are cheap (clustered, faded at 40 m), Low is the modest-PC preset.
- Its own row, not tied to an existing one, so a player can turn the marks off alone.
- Dusty prints are faint on Depot's bright slab, as dust prints are; the owner can ask for them bolder (`boot_opacity`).
- Range and Kingsmere name no marks yet (Kingsmere's models come later).

## Checks

- gdlint clean; `test_wear_marks` (9) passes with `test_graphics_table`, `test_graphics_apply`, `test_gr1_qa`,
  `test_map_data`, the settings, look, site dress and woods tests.
- Pictures (High, marks off and on): `/mnt/project-files/art/graphics/ug5/`.

## Known issues left

- A mark's box reaches 25 cm above the floor, so a figure standing on one takes it on its soles.
- Painting the pictures takes about 28 ms once per run (performance, measured headless), a little over one staged
  build slice on the loading screen of the first match; later matches reuse them. Left as it is.
