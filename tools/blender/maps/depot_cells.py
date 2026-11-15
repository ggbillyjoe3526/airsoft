"""Where each picture sits in Depot's sign sheet (DX1): assets/textures/depot/signs.png, 1024 x 1024 px, drawn by
depot_signs.py and mapped onto Depot's wall extras by depot_extras.py. Each cell is (x, y, width, height) in pixels
from the sheet's top left; its picture fills it to the edge, so mipmaps never bleed a neighbour in.
"""

SHEET = (1024, 1024)

CELLS = {
    "assembly": (0, 0, 480, 320),          # Fire assembly point, 0.6 x 0.4 m
    "fire_action": (480, 0, 240, 320),     # Fire action notice, 0.3 x 0.4 m
    "defib": (720, 0, 240, 320),           # Defibrillator, 0.3 x 0.4 m
    "no_riding": (0, 320, 240, 320),       # No riding on pallet trucks, 0.3 x 0.4 m
    "ppe": (240, 320, 384, 256),           # PPE stored here, 0.45 x 0.3 m
    "pallet_storage": (624, 320, 384, 256),  # Pallet storage area, 0.6 x 0.4 m
    "fire_exit": (0, 640, 600, 200),       # Fire exit, keep clear, 0.6 x 0.2 m
    "fire_point": (600, 640, 400, 160),    # the fire point board's header, 0.5 x 0.2 m
}


def uv(cell: str, u: float, v: float) -> tuple:
    """The sheet's UV (glTF: v down from the top) of the point (u, v) of `cell`, both 0 to 1 from its top left."""
    x, y, w, h = CELLS[cell]
    return ((x + u * w) / SHEET[0], (y + v * h) / SHEET[1])
