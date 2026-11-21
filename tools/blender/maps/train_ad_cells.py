"""Where each advert sits in the trains' advert sheet (TQ2): assets/textures/station/train_adverts.png, 2048 x 768 px,
drawn by train_adverts.py and mapped onto the cars' cove frames by train.py (train_adverts.glb). Each cell is
(x, y, width, height) in pixels from the sheet's top left, a landscape card twice as wide as it is tall; its picture
fills it to the edge, so mipmaps never bleed a neighbour in.
"""

SHEET = (2048, 768)
CELL = (512, 256)
ASPECT = CELL[0] / CELL[1]   # a card's width over its height, as train.py lays it
ADVERTS = ["ad_%s" % k for k in "abcdefghijkl"]
CELLS = {k: ((i % 4) * CELL[0], (i // 4) * CELL[1], CELL[0], CELL[1]) for i, k in enumerate(ADVERTS)}


def uv(cell: str, u: float, v: float) -> tuple:
    """The sheet's UV (glTF: v down from the top) of the point (u, v) of `cell`, both 0 to 1 from its top left."""
    x, y, w, h = CELLS[cell]
    return ((x + u * w) / SHEET[0], (y + v * h) / SHEET[1])
