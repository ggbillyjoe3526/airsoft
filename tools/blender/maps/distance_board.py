"""The range's distance boards (RM1): a cream board in a timber frame on two posts, beside each wall at every marked
distance (the number stays the game's painted text, RangeView). Plan item 11: a sign on a post.

Writes assets/models/range/distance_board.glb, one mesh a part, each laid where RangeView puts it:

  Board  the board 1.2 x 0.6 m (RangeViewConfig.sign_size) about its middle, its painted face through the origin
         facing front, the frame round it and the posts' tops behind it
  Post   a 1 m timber post from its foot (stretched to the board's height), 0.35 m either side of the middle behind
         the board

Usage: python3 tools/blender/maps/distance_board.py [--render <sheet.jpg>]
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import range_kit as rk  # noqa: E402

OUT = os.path.join(rk.RANGE, "distance_board.glb")
BUDGET = 300
W, H = 1.2, 0.6  # RangeViewConfig.sign_size
T = 0.03  # RangeViewConfig.sign_thickness
POST = 0.07
POST_X = 0.35  # either side of the middle (RangeView reads it from the model's Post)

rk.check_colours(["sign_face", "sign_frame", "post_timber", "zinc"])


def board() -> object:
    k = rk.Kit("Board")
    hw, hh = W * 0.5, H * 0.5
    f = 0.04
    # The painted sheet, and a timber frame standing 6 mm proud of it all round, then two rails behind joining the
    # posts.
    k.blk((-hw + f, 0.0, -hh + f), (hw - f, T, hh - f), "sign_face")
    k.blk((-hw, -0.006, hh - f), (hw, T, hh), "sign_frame")
    k.blk((-hw, -0.006, -hh), (hw, T, -hh + f), "sign_frame")
    k.blk((-hw, -0.006, -hh + f), (-hw + f, T, hh - f), "sign_frame")
    k.blk((hw - f, -0.006, -hh + f), (hw, T, hh - f), "sign_frame")
    for x in (-POST_X, POST_X):
        for z in (hh - 0.12, -hh + 0.12):
            k.cyl((x, -0.003, z), 0.012, 0.004, "zinc", seg=6, axis="y")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def post() -> object:
    k = rk.Kit("Post")
    h = POST * 0.5
    k.blk((-h, T, 0.0), (h, T + POST, 1.0), "post_timber")
    ob = k.build()
    rk.finish(ob)
    rk.bake(ob)
    return ob


def main() -> None:
    rk.reset()
    parts = [board(), post()]
    n = rk.report(parts, {"Post": 2})  # as RangeView draws them
    if n > BUDGET:
        raise SystemExit("over budget")
    os.makedirs(rk.RANGE, exist_ok=True)
    rk.export(OUT, parts)
    print("wrote", os.path.relpath(OUT, rk.ROOT))


if __name__ == "__main__":
    main()
