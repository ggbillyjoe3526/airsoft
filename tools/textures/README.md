# Synthesised textures

Seeded scripts (numpy and Pillow) that write tiling textures to `assets/textures/`, the same files every run.

- `concrete_floor.py`: the floor's slab set, `assets/textures/site/hall_concrete_col_2k.jpg` and
  `hall_concrete_nor_gl_2k.jpg` (DH1), from the owner's floor photos. It prints the colour map's mean linear luma,
  which goes in `SiteLook.slab_luma`.

Run: `python3 -I tools/textures/<script>.py <repo root>`, then `godot --headless --path . --import`. Dev only.

# Fetched textures

- `station_textures.gd`: Subway's station dress (MT3), the CC0 ambientCG sets `StationLook.sets` names, fetched
  from a pinned GitHub mirror into a cache folder and baked into `assets/textures/station/station_col.jpg` and
  `station_srf.png` (one 512 px layer a set; adding a set means its layer count in both `.import` files too). Run:
  `godot --headless --path . -s res://tools/textures/station_textures.gd -- <cache folder>`, then import.
