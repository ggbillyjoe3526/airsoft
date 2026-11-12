"""Where each picture sits in Subway's sign sheet (SM5): assets/textures/station/signs.png, 2048 x 1024 px, drawn by
station_signs.py and mapped onto the station's extras by station_extras.py. Each cell is (x, y, width, height) in
pixels from the sheet's top left; its picture fills it to the edge, so mipmaps never bleed a neighbour in.
"""

SHEET = (2048, 1024)

CELLS = {
    "poster_a": (0, 0, 384, 576),
    "poster_b": (384, 0, 384, 576),
    "poster_c": (768, 0, 384, 576),
    "poster_d": (1152, 0, 384, 576),
    "clock": (1536, 0, 512, 512),
    "name": (0, 576, 1024, 160),
    "edge": (0, 736, 1024, 128),
    "way_out": (1024, 576, 512, 112),
    "platforms": (1024, 688, 512, 112),
}


def uv(cell: str, u: float, v: float) -> tuple:
    """The sheet's UV (glTF: v down from the top) of the point (u, v) of `cell`, both 0 to 1 from its top left."""
    x, y, w, h = CELLS[cell]
    return ((x + u * w) / SHEET[0], (y + v * h) / SHEET[1])
