# WM1 · Wear marks: oil stains and tyre tracks on the floors

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-10 | 1 | thread | CI green on 4421a30 | Retry 6/8 | – |
| 2026-11-10 | 2 | thread | see Checks | pending | critic: Depot's marks too faint, tracks' tread toy-sized and cut off mid-road, prints dots, unnamed constants, bends' gaps |

## Goal

Step 4 of the owner's Ultra graphics (2026-11-09, `docs/ROADMAP.md`), its second half: wear decals (oil stains,
footprints, tyre marks) that add to Sunlit Concrete's procedural wear (SL1, SL2) without repeating it, every map that
names them, scaling per preset.

## Approach

- **Data:** a map's `dressing.wearMarks` (`WearMark`): oil or tyres, at x, z (y, or the ground's height), a heading,
  a length and a bend, muddy or not. Written by the map builders (`tools/depot/build_map.py`,
  `tools/woodland/build_map.py`), each placed on open floor (checked against the blocks).
- **Drawing:** `WearMarks` (built with the bushes in the dressing's staged parts): a Godot `Decal` per stain, per
  wheel per straight piece of a pair of tracks (2 m), its box half a metre tall, faces leaning past
  half from the floor faded out, distance-faded from 40 m. Colours from the look's palette (new `oil`, and `tyre_mark`
  dark enough to read on Depot's bright slab; `mud_wet`), strengths and shapes in `MarksConfig` (PlayTuning.marks).
- **Pictures:** `WearMarkArt` paints them once at load from noise, with mipmaps (without, a mark a few metres off
  faded to nothing): a ragged stain with splashes, darker and shinier (its ORM's roughness) in the middle; on a hard
  floor a smooth streaked rubber smear, outdoors a muddy tread with lugs at a real tyre's pitch (`lug_pitch`, 6.5 cm),
  each a little different; a pair's first and last pieces fade in and out over `track_fade` (1.5 m).
- **Bends:** each wheel is laid along its own path, set off square to the middle's at every point, so on a bend the
  pieces still meet end to end.
- **Graphics row** Wear marks, off on Low, on from Medium (Forward+ and Mobile: Compatibility draws no decals), under
  Light and detail, set by `GraphicsApply.apply_field`.
- **Placed:** Depot 12 (8 oil, 4 tracks: Loading bay, Garage, the hall's forklift lanes), 54 decals;
  Woodland 2 (the pickup's muddy tracks from the culvert's wet banks along the road to the verge where it stands, an
  oil drip by it), 29 decals.

## Defaults taken

- **No boot prints (owner, 2026-11-10):** attempt 2's prints were taken out at his word; the marks are oil and
  tyres only.
- Medium and up: decals are cheap (clustered, faded at 40 m), Low is the modest-PC preset.
- Its own row, not tied to an existing one, so a player can turn the marks off alone.
- Range and Kingsmere name no marks yet (Kingsmere's models come later).

## Checks

- gdlint clean; `test_wear_marks` (9) and QA's `test_wm1_qa` (19: malformed marks, old and corrupt saves,
  Compatibility, teardown, bounded long marks, reproducible map builders) pass, with `test_graphics_table`, `test_graphics_apply`, `test_gr1_qa`,
  `test_map_data`, the settings, look, site dress and woods tests.
- Pictures (High, marks off and on): `/mnt/project-files/art/graphics/ug5/`.

## Known issues left

- A mark's box reaches 25 cm above the floor, so a figure standing on one takes it on its soles.
- Painting the pictures takes about 47 ms once per run (measured headless; the muddy tread's real-scale lugs need a
  longer picture), a few staged build slices on the loading screen of the first match; later matches reuse them.
  Left as it is.
