"""Where each picture sits in Subway's sign sheet (SM5): assets/textures/station/signs.png, 2048 x 2048 px, drawn by
station_signs.py and mapped onto the station's extras by station_extras.py. Each cell is (x, y, width, height) in
pixels from the sheet's top left; its picture fills it to the edge, so mipmaps never bleed a neighbour in.
"""

SHEET = (2048, 2048)
POSTER = (336, 504)   # a poster's cell: 1 x 1.5 m at 336 px a metre
POSTERS = ["poster_%s" % k for k in "abcdefghijklm"]
WIDE = (672, 336)     # a trackside poster's cell: 3 x 1.5 m at 224 px a metre
WIDE_POSTERS = ["poster_wide_%s" % k for k in "abc"]

CELLS = {k: ((i % 6) * POSTER[0], (i // 6) * POSTER[1], POSTER[0], POSTER[1]) for i, k in enumerate(POSTERS[:12])}
CELLS.update({
    "poster_m": (1536, 1008, POSTER[0], POSTER[1]),
    "name": (0, 1008, 1024, 160),
    "edge": (0, 1168, 1024, 128),
    "way_out": (0, 1296, 512, 112),
    "platforms": (512, 1296, 512, 112),
    "clock": (1024, 1008, 512, 512),
})
CELLS.update({k: (i * WIDE[0], 1536, WIDE[0], WIDE[1]) for i, k in enumerate(WIDE_POSTERS)})

def uv(cell: str, u: float, v: float) -> tuple:
    """The sheet's UV (glTF: v down from the top) of the point (u, v) of `cell`, both 0 to 1 from its top left."""
    x, y, w, h = CELLS[cell]
    return ((x + u * w) / SHEET[0], (y + v * h) / SHEET[1])
