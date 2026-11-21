# Synthesised textures

Seeded scripts (numpy and Pillow) that write tiling textures to `assets/textures/`, the same files every run.

- `concrete_floor.py`: the floor's slab set, `assets/textures/site/hall_concrete_col_2k.jpg` and
  `hall_concrete_nor_gl_2k.jpg` (DH1), from the owner's floor photos. It prints the colour map's mean linear luma,
  which goes in `SiteLook.slab_luma`.

- `replica_grain.py`: the replicas' surface grain, `assets/textures/replica/replica_grain.png` (MQ1): one 512 px
  tiling texture every replica and part shares (a moulded pebble's slope, a slow sheen cloud, wood figure with
  arched, unevenly spaced rings), read by `game/play/replica_surface.gdshaderinc`. It is imported Lossless with
  mipmaps, not VRAM compressed: its four channels are unrelated data (two slopes, a cloud, the figure), and block
  compression ties a block's channels together and bands the slopes into visible steps on a smooth slide. It is one
  512 px texture for the whole game (about 1.4 MB of video memory with its mipmaps).

Run: `python3 -I tools/textures/<script>.py <repo root>`, then `godot --headless --path . --import`. Dev only.

# Fetched textures

- `station_textures.gd`: Subway's station dress (MT3), the CC0 ambientCG sets `StationLook.sets` names, fetched
  from a pinned GitHub mirror into a cache folder and baked into `assets/textures/station/station_col.jpg` and
  `station_srf.png` (one 512 px layer a set; adding a set means its layer count in both `.import` files too). Run:
  `godot --headless --path . -s res://tools/textures/station_textures.gd -- <cache folder>`, then import.
- `woodland_fetch.gd` and `woodland_textures.py`: Woodland's detail textures (WQ1). The fetch script takes the CC0
  ambientCG sets it names (barks, planks, concrete, steel, ground, moss) from the same pinned mirror into a cache
  folder as PNGs; the Python script composes `assets/textures/woodland/`: the barks and their normal maps
  (`bark_pine`, `bark_flake`, `bark_oak`, and `bark_birch` drawn whole), the 2,048 px leaf sheet `leaves.png`
  (16 cells, drawn: needle shoots, sprays, fronds, masses and twigs, `treekit.CELLS` order), and the surfaces array
  `surfaces.png` with `surfaces_nor.png` (8 layers of 512 px in a row, `mapkit.SURFACES` order; their `.import` files
  are 2D arrays of 8 slices). Every map is stored at half strength (0.5 draws the paint as it is). Run:
  `godot --headless --path . -s res://tools/textures/woodland_fetch.gd -- <cache>`, then
  `python3 -I tools/textures/woodland_textures.py <repo root> <cache>`, then import.
