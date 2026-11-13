"""Stockade's quick checks (SK1), before the game's own field checks: blocks standing inside each other (the layout's
boxes, before they are written), then, on the written map file, the longest standing sight lines between places to
stand, by MB1's sight raster (tools/maps/los.py). Its pictures and report come from tools/maps/plan.py.

    python3 tools/stockade/build_map.py && python3 tools/stockade/check.py [step m]
    python3 tools/maps/plan.py stockade --out <dir>          # the plan picture

Needs numpy. The game's FieldChecks are the judge (tests/unit/test_field_rules.gd, test_field_layout.gd: its sight
measure stands at eye height on the nav grid's own cells, and finds threads a coarser grid misses); this is the fast
look while placing cover."""
from __future__ import annotations

import os
import sys

import numpy as np

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "..", "maps"))
import layout as L  # noqa: E402
import los  # noqa: E402
import plan as P  # noqa: E402

LIMIT = 34.0        # FieldStandard.LONGEST_SIGHTLINE
SEAM = 0.025        # FieldStandard.SEAM_SLACK


def all_boxes() -> list[dict]:
    """Every solid box of the layout: its blocks, the trees' trunks, the doors that start a round shut
    (MapLevel._add_doors; an open one swings clear) and the roofs."""
    out = list(L.boxes)
    for (x, z, rad, model, height) in L.TREES:
        out.append({"kind": "tree", "x1": x - rad, "z1": z - rad, "x2": x + rad, "z2": z + rad, "y1": -L.SINK,
                    "y2": height, "dress": model})
    for d in L.DOORS:
        if d["shut"]:
            out.append({"kind": "door", "x1": d["x"] - d["sx"] / 2, "z1": d["z"] - d["sz"] / 2,
                        "x2": d["x"] + d["sx"] / 2, "z2": d["z"] + d["sz"] / 2, "y1": 0.0, "y2": L.WALL,
                        "dress": "door"})
    for t in L.ROOF_TILES:
        out.append({"kind": "plywood", "x1": t["x1"], "z1": t["z1"], "x2": t["x2"], "z2": t["z2"], "y1": t["y"],
                    "y2": t["y"] + L.ROOF_T, "dress": "roof"})
    return out


def overlaps(boxes: list[dict]) -> list[str]:
    """Pairs of boxes sharing more than FieldStandard.SEAM_SLACK each way (pieces that meet run 1 cm into each other)."""
    out = []
    for i, a in enumerate(boxes):
        for b in boxes[i + 1:]:
            if (min(a["x2"], b["x2"]) - max(a["x1"], b["x1"]) > SEAM
                    and min(a["z2"], b["z2"]) - max(a["z1"], b["z1"]) > SEAM
                    and min(a["y2"], b["y2"]) - max(a["y1"], b["y1"]) > SEAM):
                out.append("%s %s at (%.1f, %.1f) stands in %s %s at (%.1f, %.1f)" % (
                    a["kind"], a.get("dress", ""), (a["x1"] + a["x2"]) / 2, (a["z1"] + a["z2"]) / 2,
                    b["kind"], b.get("dress", ""), (b["x1"] + b["x2"]) / 2, (b["z1"] + b["z2"]) / 2))
    return out


def blocked(boxes: list[dict], ax: float, az: float, bx: float, bz: float, eye: float = los.EYE) -> bool:
    """Whether a box stands across the eye-high segment from (ax, az) to (bx, bz): the exact test behind the raster,
    which lets a line slip diagonally past the corner of a wall thinner than its cells. Stockade's ground is flat."""
    for k in boxes:
        if not k["y1"] < eye < k["y2"]:
            continue
        t0, t1 = 0.0, 1.0
        for (p, q, lo, hi) in ((ax, bx, k["x1"], k["x2"]), (az, bz, k["z1"], k["z2"])):
            d = q - p
            if abs(d) < 1e-9:
                if not lo <= p <= hi:
                    t0 = 2.0
                    break
                continue
            u, v = sorted(((lo - p) / d, (hi - p) / d))
            t0, t1 = max(t0, u), min(t1, v)
            if t0 > t1:
                break
        if t0 <= t1:
            return True
    return False


def long_lines(sight: los.Sight, boxes: list[dict], step: float) -> list[tuple[float, float, float, float, float]]:
    """Each stand point's longest clear standing line over LIMIT to a stand point (both on a `step` grid): the raster
    finds the candidates, the exact box test keeps the ones nothing stands across."""
    xs, zs = sight.stand_points(step)
    out = []
    for k in range(len(xs)):
        d = np.hypot(xs[k + 1:] - xs[k], zs[k + 1:] - zs[k])
        far = np.nonzero(d > LIMIT)[0] + k + 1
        if far.size == 0:
            continue
        ok = sight.sees(xs[k], zs[k], xs[far], zs[far])
        seen = [j for j in far[ok] if not blocked(boxes, xs[k], zs[k], xs[j], zs[j])]
        if seen:
            j = max(seen, key=lambda j: np.hypot(xs[j] - xs[k], zs[j] - zs[k]))
            out.append((float(np.hypot(xs[j] - xs[k], zs[j] - zs[k])), xs[k], zs[k], xs[j], zs[j]))
    return sorted(out, reverse=True)


def main() -> None:
    step = float(sys.argv[1]) if len(sys.argv) > 1 else 1.5
    boxes = all_boxes()
    bad = overlaps(boxes)
    for line in bad[:20]:
        print("OVERLAP", line)
    lines = long_lines(los.Sight(P.Field("stockade")), boxes, step)
    for (ln, x1, z1, x2, z2) in lines[:20]:
        print("LINE %.1f m: (%.1f, %.1f) to (%.1f, %.1f)" % (ln, x1, z1, x2, z2))
    print("TOTAL %d overlaps, %d stand points with a line over %.0f m (longest %.1f m)" % (
        len(bad), len(lines), LIMIT, lines[0][0] if lines else 0.0))


if __name__ == "__main__":
    main()
