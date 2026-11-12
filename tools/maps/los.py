"""Sight over a field's plan, quickly (MB1; dev only): a 2.5D ray march over the map file's terrain and blocks, for
trying a layout change before the game's own survey (tools/map_survey.gd) measures it. One floor only: Depot and
Woodland, not Subway's storeys.

  python3 tools/maps/los.py <map id> lanes            # each lane's first contact: where two squads first see each other
  python3 tools/maps/los.py <map id> view x z [out]   # what a standing eye at (x, z) sees, drawn
"""
from __future__ import annotations

import json
import math
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
import plan as P  # noqa: E402

EYE = 1.66
RES = 0.25
RUN = 4.2


class Sight:
    def __init__(self, field: P.Field):
        self.f = field
        self.x0, self.z0 = field.x0, field.z0
        self.nx = int(math.ceil((field.x1 - field.x0) / RES))
        self.nz = int(math.ceil((field.z1 - field.z0) / RES))
        xs = self.x0 + (np.arange(self.nx) + 0.5) * RES
        zs = self.z0 + (np.arange(self.nz) + 0.5) * RES
        if field.terrain:
            t = field.terrain
            fi = np.clip((xs - t["minX"]) / t["cell"], 0, t["cols"] - 1e-6)
            fj = np.clip((zs - t["minZ"]) / t["cell"], 0, t["rows"] - 1e-6)
            i0, j0 = fi.astype(int), fj.astype(int)
            u, v = fi - i0, fj - j0
            H = field.heights
            self.ground = ((H[np.ix_(j0, i0)] * (1 - u)[None, :] + H[np.ix_(j0, i0 + 1)] * u[None, :]) * (1 - v)[:, None]
                           + (H[np.ix_(j0 + 1, i0)] * (1 - u)[None, :] + H[np.ix_(j0 + 1, i0 + 1)] * u[None, :]) * v[:, None])
        else:
            self.ground = np.zeros((self.nz, self.nx))
        self.solid = self.ground.copy()            # the top of what stands on the ground
        self.up_lo = np.full((self.nz, self.nx), np.inf)   # a lintel or roof: from here
        self.up_hi = np.full((self.nz, self.nx), -np.inf)  # to here
        self.walk = np.ones((self.nz, self.nx), bool)
        for b in field.d["blocks"]:
            c, s = b["center"], b["size"]
            if b["kind"] == "floor" and not field.terrain:
                continue
            i1 = max(0, int(round((c["x"] - s["x"] / 2 - self.x0) / RES)))
            i2 = min(self.nx, max(i1 + 1, int(round((c["x"] + s["x"] / 2 - self.x0) / RES))))
            j1 = max(0, int(round((c["z"] - s["z"] / 2 - self.z0) / RES)))
            j2 = min(self.nz, max(j1 + 1, int(round((c["z"] + s["z"] / 2 - self.z0) / RES))))
            bottom, top = c["y"] - s["y"] / 2, c["y"] + s["y"] / 2
            g = self.ground[j1:j2, i1:i2]
            if b["kind"] in ("floor", "ramp"):
                continue
            if bottom - g.mean() > 0.6:
                self.up_lo[j1:j2, i1:i2] = np.minimum(self.up_lo[j1:j2, i1:i2], bottom)
                self.up_hi[j1:j2, i1:i2] = np.maximum(self.up_hi[j1:j2, i1:i2], top)
            else:
                self.solid[j1:j2, i1:i2] = np.maximum(self.solid[j1:j2, i1:i2], top)
                if top - g.mean() > 0.35:
                    self.walk[j1:j2, i1:i2] = False

        # Leaves hide and stop BBs but are walked through (FO1): a bush stops a standing eye's line, a fern bed a low one.
        for fo in field.d.get("foliage", []):
            r = fo["radius"]
            i1 = max(0, int((fo["x"] - r - self.x0) / RES))
            i2 = min(self.nx, int((fo["x"] + r - self.x0) / RES) + 1)
            j1 = max(0, int((fo["z"] - r - self.z0) / RES))
            j2 = min(self.nz, int((fo["z"] + r - self.z0) / RES) + 1)
            xs2 = self.x0 + (np.arange(i1, i2) + 0.5) * RES
            zs2 = self.z0 + (np.arange(j1, j2) + 0.5) * RES
            inside = (xs2[None, :] - fo["x"]) ** 2 + (zs2[:, None] - fo["z"]) ** 2 <= r * r
            top = np.where(inside, fo["y"] + fo["height"], -np.inf)
            self.solid[j1:j2, i1:i2] = np.maximum(self.solid[j1:j2, i1:i2], top)

    def cell(self, x, z):
        i = np.clip(((np.asarray(x) - self.x0) / RES).astype(int), 0, self.nx - 1)
        j = np.clip(((np.asarray(z) - self.z0) / RES).astype(int), 0, self.nz - 1)
        return j, i

    def floor(self, x, z):
        j, i = self.cell(x, z)
        return self.ground[j, i]

    def sees(self, ax, az, bx, bz, eye_a=EYE, eye_b=EYE):
        """Whether an eye over (ax, az) sees a point eye_b over each (bx, bz): arrays of targets."""
        bx, bz = np.asarray(bx, float), np.asarray(bz, float)
        ya = float(self.floor(ax, az)) + eye_a
        yb = self.floor(bx, bz) + eye_b
        d = np.hypot(bx - ax, bz - az)
        n = int(max(2, math.ceil(d.max() / (RES * 0.8)))) if d.size else 2
        ok = np.ones(bx.shape, bool)
        for k in range(1, n):
            t = k / n
            x, z = ax + (bx - ax) * t, az + (bz - az) * t
            y = ya + (yb - ya) * t
            j, i = self.cell(x, z)
            ok &= (y > self.solid[j, i]) & ~((y > self.up_lo[j, i]) & (y < self.up_hi[j, i]))
        return ok

    def stand_points(self, step=1.0):
        xs = np.arange(self.f.x0 + step / 2, self.f.x1, step)
        zs = np.arange(self.f.z0 + step / 2, self.f.z1, step)
        gx, gz = np.meshgrid(xs, zs)
        gx, gz = gx.ravel(), gz.ravel()
        j, i = self.cell(gx, gz)
        m = self.walk[j, i]
        return gx[m], gz[m]


def along(path, step=1.0):
    """Points every `step` m along a polyline, and their distance from its start."""
    out, s = [], 0.0
    for (ax, az), (bx, bz) in zip(path, path[1:]):
        L = math.hypot(bx - ax, bz - az)
        for t in np.arange(0, L, step):
            out.append((ax + (bx - ax) * t / L, az + (bz - az) * t / L, s + t))
        s += L
    out.append((path[-1][0], path[-1][1], s))
    return np.array(out)


def lane_contacts(field: P.Field, sight: Sight, out=sys.stdout):
    """Each lane walked from both ends at a run: when and how far apart the two walkers first see each other, and
    how the range closes after (the share of the next 20 s' steps they stay in sight)."""
    for k, lane in enumerate(field.d["lanes"]):
        pts = along([(p["x"], p["z"]) for p in lane])
        total = pts[-1, 2]
        s0 = field.d["spawns"][0][0]["position"]
        s1 = field.d["spawns"][1][0]["position"]
        lead0 = math.hypot(pts[0, 0] - s0["x"], pts[0, 1] - s0["z"])
        lead1 = math.hypot(pts[-1, 0] - s1["x"], pts[-1, 1] - s1["z"])
        first = None
        ranges = []
        for t in np.arange(0, 80, 0.5):
            a = np.interp(max(0.0, t * RUN - lead0), pts[:, 2], np.arange(len(pts)))
            b = np.interp(max(0.0, total - max(0.0, t * RUN - lead1)), pts[:, 2], np.arange(len(pts)))
            if a >= b:
                break
            pa, pb = pts[int(a)], pts[int(b)]
            d = math.hypot(pa[0] - pb[0], pa[1] - pb[1])
            if sight.sees(pa[0], pa[1], np.array([pb[0]]), np.array([pb[1]]))[0]:
                if first is None:
                    first = (t, d, pa, pb)
                ranges.append(d)
        name = "nms"[k] if k < 3 else str(k)
        if first is None:
            out.write("lane %s: the walkers never see each other before they meet\n" % name)
            continue
        t, d, pa, pb = first
        out.write("lane %s: first contact at %.0f s, %.0f m apart: (%.0f, %.0f) in %s sees (%.0f, %.0f) in %s; in sight "
                  "for %d of the steps after\n" % (name, t, d, pa[0], pa[1], field.area_of(pa[0], 0, pa[1]), pb[0], pb[1],
                                                   field.area_of(pb[0], 0, pb[1]), len(ranges)))


def view(field: P.Field, sight: Sight, x: float, z: float, path: str, reach: float = 60.0, eye_b: float = EYE):
    import matplotlib.pyplot as plt
    gx, gz = sight.stand_points(1.0)
    m = np.hypot(gx - x, gz - z) <= reach
    gx, gz = gx[m], gz[m]
    ok = sight.sees(x, z, gx, gz, EYE, eye_b)
    fig, axes, order = P.figure(field, "%s: what a standing eye at (%.0f, %.0f) sees within %.0f m (red)" % (
        field.d.get("name", field.id), x, z, reach))
    P.draw_plan(field, axes[0], 0)
    axes[0].scatter(gx[ok], gz[ok], s=5, color="#d62728", alpha=0.6, zorder=5, lw=0)
    axes[0].scatter([x], [z], s=60, color="k", marker="x", zorder=6)
    fig.tight_layout()
    fig.savefig(path, dpi=100)
    plt.close(fig)
    return int(ok.sum())


if __name__ == "__main__":
    f = P.Field(sys.argv[1])
    s = Sight(f)
    if sys.argv[2] == "lanes":
        lane_contacts(f, s)
    else:
        n = view(f, s, float(sys.argv[3]), float(sys.argv[4]), sys.argv[5] if len(sys.argv) > 5 else "/tmp/view.png")
        print(n, "spots seen")
