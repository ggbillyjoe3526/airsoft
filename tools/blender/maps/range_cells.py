"""Where each picture sits in the Range's sign sheet (RQ1): assets/textures/range/signs.png, 1024 x 1024 px, drawn by
range_signs.py and mapped onto the Range's extras by range_extras.py. Each cell is (x, y, width, height) in pixels
from the sheet's top left; its picture fills it to the edge, so mipmaps never bleed a neighbour in.
"""

SHEET = (1024, 1024)

CELLS = {
    "rules": (0, 0, 480, 640),           # the range rules board, 0.9 x 1.2 m
    "chrono": (480, 0, 480, 240),        # the chrono station sign, 0.6 x 0.3 m
    "eye_pro": (480, 240, 360, 240),     # eye protection must be worn, 0.45 x 0.3 m
    "lane_1": (480, 480, 128, 128),      # the lanes' numbers on the shelter's front, 0.3 x 0.3 m
    "lane_2": (608, 480, 128, 128),
    "lane_3": (736, 480, 128, 128),
    "lane_4": (864, 480, 128, 128),
    "safe_zone": (0, 640, 600, 200),     # safe zone, barrel bags on, 0.6 x 0.2 m
    "range_hot": (600, 640, 400, 200),   # red flag up, range hot, 0.4 x 0.2 m
}


def uv(cell: str, u: float, v: float) -> tuple:
    """The sheet's UV (glTF: v down from the top) of the point (u, v) of `cell`, both 0 to 1 from its top left."""
    x, y, w, h = CELLS[cell]
    return ((x + u * w) / SHEET[0], (y + v * h) / SHEET[1])
