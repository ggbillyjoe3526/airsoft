"""A field's plan, its play record and its survey, drawn and counted (MB1; dev only).

Reads data/maps/<id>.json (the blocks the game plays on, never a layout script), a play record written by
tools/map_heat.gd and a survey written by tools/map_survey.gd, and writes labelled pictures (one panel a storey) and
a text report: who wins, where the fights are, where each end walks, what stands open.

  python3 tools/maps/plan.py <map id> --out <dir> [--heat a.json b.json ...] [--survey s.json] [--label "before"]
"""
from __future__ import annotations

import argparse
import json
import math
import os
from collections import Counter, defaultdict

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
from matplotlib.patches import Rectangle  # noqa: E402

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
EYE = 1.5          # a standing eye over the floor (m)
CROUCH = 1.0       # a crouched body is hidden behind anything this tall
STEP = 0.35        # lower than this is walked over
RUN = 4.2          # m/s, a bot's run
END_COLOURS = ["#e8742a", "#2a7fe8"]   # end 0 (the west / street end), end 1
END_NAMES = {"depot": ["West (Staging)", "East (Loading bay)"], "woodland": ["West camp", "East camp"],
             "subway": ["Street (ticket hall)", "Tunnel"]}
REASONS = ["everyone out", "time", "flag raised", "overtime flag", "simulated"]


def load_map(map_id: str) -> dict:
    with open(os.path.join(ROOT, "data", "maps", map_id + ".json")) as f:
        return json.load(f)


class Field:
    def __init__(self, map_id: str):
        self.id = map_id
        self.d = load_map(map_id)
        self.storeys = self.d.get("storeys") or [0.0]
        self.terrain = self.d.get("terrain")
        xs, zs = [], []
        for b in self.d["blocks"]:
            c, s = b["center"], b["size"]
            xs += [c["x"] - s["x"] / 2, c["x"] + s["x"] / 2]
            zs += [c["z"] - s["z"] / 2, c["z"] + s["z"] / 2]
        if self.terrain:
            t = self.terrain
            xs += [t["minX"], t["minX"] + t["cell"] * t["cols"]]
            zs += [t["minZ"], t["minZ"] + t["cell"] * t["rows"]]
        self.x0, self.x1, self.z0, self.z1 = min(xs), max(xs), min(zs), max(zs)
        if self.terrain:
            t = self.terrain
            self.heights = np.array(t["heights"]).reshape(t["rows"] + 1, t["cols"] + 1)

    def ground(self, x: float, z: float) -> float:
        if not self.terrain:
            return 0.0
        t = self.terrain
        i = min(max(int((x - t["minX"]) / t["cell"]), 0), t["cols"] - 1)
        j = min(max(int((z - t["minZ"]) / t["cell"]), 0), t["rows"] - 1)
        return float(self.heights[j, i])

    def storey_of(self, y: float) -> int:
        """The storey a floor height belongs to: the highest one at or under y + half a storey."""
        best = 0
        for k, s in enumerate(self.storeys):
            if y >= s - 4.0:
                best = k
        return best

    def area_of(self, x: float, y: float, z: float) -> str:
        best = ""
        for a in self.d.get("areas", []):
            bx = a["box"]
            if bx[0] <= x <= bx[1] and bx[2] <= z <= bx[3]:
                fl = a.get("floor")
                if fl and not (fl[0] - 0.6 <= y <= fl[1] + 0.6):
                    continue
                best = a["name"]
                if fl:
                    return best
        return best or "?"

    def floor_under(self, x: float, z: float, bottom: float) -> float:
        """The top of the highest floor block under a point at or below `bottom` (a storeyed map), else the ground."""
        if self.terrain:
            return self.ground(x, z)
        best = None
        for (fx0, fx1, fz0, fz1, top) in self._floors():
            if fx0 <= x <= fx1 and fz0 <= z <= fz1 and top <= bottom + 0.2 and (best is None or top > best):
                best = top
        return 0.0 if best is None else best

    def _floors(self):
        if not hasattr(self, "_floor_list"):
            self._floor_list = []
            for b in self.d["blocks"]:
                if b["kind"] == "floor":
                    c, s = b["center"], b["size"]
                    self._floor_list.append((c["x"] - s["x"] / 2, c["x"] + s["x"] / 2, c["z"] - s["z"] / 2,
                                             c["z"] + s["z"] / 2, c["y"] + s["y"] / 2))
        return self._floor_list

    def blocks_on(self, storey: int):
        """(x, z, sx, sz, class, kind) of every block standing on a storey: tall (stops a standing eye), low (crouch
        cover), flat; a floor block is "floor" (walkable ground on a storeyed map)."""
        base = self.storeys[storey]
        many = len(self.storeys) > 1
        out = []
        for b in self.d["blocks"]:
            c, s = b["center"], b["size"]
            bottom, top = c["y"] - s["y"] / 2, c["y"] + s["y"] / 2
            if b["kind"] == "floor":
                if many and base - 0.2 <= top <= base + 1.2:
                    out.append((c["x"], c["z"], s["x"], s["z"], "floor" if top < base + 0.5 else "floor2", b["kind"]))
                continue
            if many and not (bottom < base + 3.0 and top > base + 0.1):
                continue
            floor = self.floor_under(c["x"], c["z"], bottom) if many else self.ground(c["x"], c["z"])
            if many and not (base - 0.2 <= floor <= base + 1.2) and not b.get("rise"):
                # a wall through several storeys: judged from this storey's floor
                floor = base
            rel_top, rel_bottom = top - floor, bottom - floor
            if b.get("rise"):
                cls = "ramp"
            elif rel_bottom > EYE:
                cls = "over"
            elif rel_top >= EYE and rel_bottom < EYE:
                cls = "tall" if rel_bottom < CROUCH else "lintel"
            elif rel_top >= CROUCH * 0.8:
                cls = "low"
            elif rel_top > STEP:
                cls = "kerb"
            else:
                cls = "flat"
            out.append((c["x"], c["z"], s["x"], s["z"], cls, b["kind"]))
        order = {"floor": 0, "floor2": 1, "ramp": 2}
        out.sort(key=lambda r: order.get(r[4], 3))
        return out


CLASS_STYLE = {"tall": ("#3a3f47", 1.0), "low": ("#9aa3ad", 1.0), "kerb": ("#c9ced4", 1.0), "lintel": ("#3a3f47", 0.35),
               "ramp": ("#d9c9a8", 0.9), "over": ("#3a3f47", 0.12), "flat": ("#e4e6e8", 0.5),
               "floor": ("#f4f2ee", 1.0), "floor2": ("#fbfaf7", 1.0)}
KIND_COLOUR = {"tree": "#4d6b45", "thicket": "#2f4a2c", "net": "#5d6f7d"}


def draw_plan(field: Field, ax, storey: int, labels: bool = True, faint: bool = False):
    ax.set_facecolor("#f4f2ee" if len(field.storeys) == 1 else "#b9b6b0")
    if field.terrain:
        t = field.terrain
        ext = [t["minX"], t["minX"] + t["cell"] * t["cols"], t["minZ"] + t["cell"] * t["rows"], t["minZ"]]
        ax.imshow(field.heights, extent=ext, cmap="Greens_r", alpha=0.35, vmin=-3, vmax=9, zorder=0)
        for w in field.d.get("water", []):
            ax.plot([p["x"] for p in w["points"]], [p["z"] for p in w["points"]], color="#6fa8dc", lw=3, alpha=0.7,
                    zorder=1)
        for f in field.d.get("foliage", []):
            ax.add_patch(plt.Circle((f["x"], f["z"]), f["radius"], color="#8fbf6f", alpha=0.35, lw=0, zorder=1))
    for (x, z, sx, sz, cls, kind) in field.blocks_on(storey):
        col, alpha = CLASS_STYLE[cls]
        if cls == "tall" and kind in KIND_COLOUR:
            col = KIND_COLOUR[kind]
        ax.add_patch(Rectangle((x - sx / 2, z - sz / 2), sx, sz, color=col, alpha=alpha * (0.45 if faint else 1.0), lw=0,
                               zorder=2))
    base = field.storeys[storey]
    for d in field.d.get("doors", []):
        c, s = d["center"], d["size"]
        ax.add_patch(Rectangle((c["x"] - s["x"] / 2 - 0.1, c["z"] - s["z"] / 2 - 0.1), s["x"] + 0.2, s["z"] + 0.2,
                               color="#b5651d" if d.get("shut") else "#e0a96d", lw=0, zorder=3))
    for end, spawns in enumerate(field.d["spawns"]):
        pts = [s["position"] for s in spawns if field.storey_of(s["position"]["y"]) == storey]
        if pts:
            ax.scatter([p["x"] for p in pts], [p["z"] for p in pts], s=14, color=END_COLOURS[end], zorder=6,
                       edgecolors="k", linewidths=0.4)
    for k, f in enumerate(field.d.get("flags", [])):
        if field.storey_of(f["y"]) == storey:
            ax.scatter([f["x"]], [f["z"]], marker="P", s=130, color="#ffd400", edgecolors="k", zorder=7)
            ax.annotate("AB"[k], (f["x"], f["z"]), fontsize=9, fontweight="bold", ha="center", va="center", zorder=8)
    ot = field.d.get("overtimeFlag")
    if ot and field.storey_of(ot["y"]) == storey:
        ax.scatter([ot["x"]], [ot["z"]], marker="*", s=160, color="#ffffff", edgecolors="k", zorder=7)
    if labels:
        seen = {}
        for a in field.d.get("areas", []):
            bx = a["box"]
            fl = a.get("floor")
            y = fl[0] + 0.5 if fl else base
            if len(field.storeys) > 1 and field.storey_of(y) != storey:
                continue
            seen.setdefault(a["name"], []).append(bx)
        for name, boxes in seen.items():
            wsum = sum((b[1] - b[0]) * (b[3] - b[2]) for b in boxes)
            cx = sum((b[0] + b[1]) / 2 * (b[1] - b[0]) * (b[3] - b[2]) for b in boxes) / wsum
            cz = sum((b[2] + b[3]) / 2 * (b[1] - b[0]) * (b[3] - b[2]) for b in boxes) / wsum
            ax.annotate(name, (cx, cz), fontsize=6.5, ha="center", va="center", color="#1c1c1c", zorder=9,
                        bbox=dict(boxstyle="round,pad=0.15", fc="white", ec="none", alpha=0.6))
    ax.set_xlim(field.x0, field.x1)
    ax.set_ylim(field.z1, field.z0)
    ax.set_aspect("equal")
    ax.tick_params(labelsize=6)


def figure(field: Field, title: str):
    n = len(field.storeys)
    w = field.x1 - field.x0
    h = field.z1 - field.z0
    fw = 15.0
    fh = fw * h / w * n + 0.9 * n + 0.6
    fig, axes = plt.subplots(n, 1, figsize=(fw, fh), squeeze=False)
    names = ["Platforms and track", "Concourse", "Ticket hall"] if n == 3 else [""]
    order = list(range(n))[::-1]   # top storey first
    for row, storey in enumerate(order):
        axes[row][0].set_title((names[storey] + "  " if names[storey] else "") + (title if row == 0 else ""), fontsize=11,
                               loc="left")
    return fig, [axes[r][0] for r in range(n)], order


def grid_of(field: Field, cell: float):
    nx = int(math.ceil((field.x1 - field.x0) / cell))
    nz = int(math.ceil((field.z1 - field.z0) / cell))
    return nx, nz


def heat_layers(field: Field, rows: np.ndarray, cell: float, pick):
    """rows: (n, k) samples with x, y, z at columns pick; returns a count grid a storey."""
    nx, nz = grid_of(field, cell)
    out = [np.zeros((nz, nx)) for _ in field.storeys]
    if rows.size == 0:
        return out
    xs, ys, zs = rows[:, pick[0]], rows[:, pick[1]], rows[:, pick[2]]
    for k in range(len(field.storeys)):
        if len(field.storeys) > 1:
            st = np.array([field.storey_of(y) for y in ys])
            m = st == k
        else:
            m = np.ones(len(xs), bool)
        i = np.clip(((xs[m] - field.x0) / cell).astype(int), 0, nx - 1)
        j = np.clip(((zs[m] - field.z0) / cell).astype(int), 0, nz - 1)
        np.add.at(out[k], (j, i), 1)
    return out


def blur(a: np.ndarray, n: int = 1) -> np.ndarray:
    for _ in range(n):
        p = np.pad(a, 1, mode="edge")
        a = (p[:-2, 1:-1] + p[2:, 1:-1] + p[1:-1, :-2] + p[1:-1, 2:] + 4 * p[1:-1, 1:-1]) / 8.0
    return a


def show(field: Field, ax, grid: np.ndarray, cmap: str, vmax: float | None = None, alpha: float = 0.8):
    g = np.ma.masked_less_equal(grid, (vmax or grid.max() or 1) * 0.02)
    ax.imshow(g, extent=[field.x0, field.x1, field.z1, field.z0], cmap=cmap, alpha=alpha, vmin=0,
              vmax=vmax or (np.percentile(grid[grid > 0], 99) if (grid > 0).any() else 1), zorder=4,
              interpolation="bilinear")


def load_heat(paths: list[str]):
    stood, hits, rounds, meta = [], [], [], {}
    for p in paths:
        with open(p) as f:
            d = json.load(f)
        meta = {k: d[k] for k in ("map", "mode", "size")}
        stood.append(np.array(d["stood"], dtype=float).reshape(-1, 5))
        hits.append(np.array(d["hits"], dtype=float).reshape(-1, 8))
        rounds += d["rounds"]
    return np.concatenate(stood), np.concatenate(hits), rounds, meta


def pct(a: float, b: float) -> str:
    return "%.0f %%" % (100.0 * a / b) if b else "-"


def report(field: Field, stood, hits, rounds, meta, survey, out) -> None:
    w = out.write
    names = END_NAMES.get(field.id, ["End 0", "End 1"])
    if rounds:
        mode = meta["mode"]
        decided = [r for r in rounds if r["winner"] >= 0]
        w("## %s, %s, %dv%d: %d rounds (%d decided)\n" % (field.id, "Attack / Defend" if mode == "flag" else
                                                          "Elimination", meta["size"], meta["size"], len(rounds),
                                                          len(decided)))
        # which END won: alpha is team 0; alpha_end is its end this round.
        end_wins = [0, 0]
        for r in decided:
            end_wins[r["alpha_end"] if r["winner"] == 0 else 1 - r["alpha_end"]] += 1
        se = 100 * math.sqrt(0.25 / max(len(decided), 1))
        w("- Rounds won by end: %s %s, %s %s (±%.0f)\n" % (names[0], pct(end_wins[0], len(decided)), names[1],
                                                         pct(end_wins[1], len(decided)), se))
        if mode == "flag":
            att = sum(1 for r in decided if r["winner"] == r["attackers"])
            w("- Attackers won %s of decided rounds\n" % pct(att, len(decided)))
            by_end = defaultdict(lambda: [0, 0])
            for r in decided:
                att_end = r["alpha_end"] if r["attackers"] == 0 else 1 - r["alpha_end"]
                by_end[att_end][0] += r["winner"] == r["attackers"]
                by_end[att_end][1] += 1
            for e, (a, n) in sorted(by_end.items()):
                w("  - attacking from %s: %s of %d\n" % (names[e], pct(a, n), n))
        why = Counter(r["reason"] for r in rounds)
        w("- Ended by: %s\n" % ", ".join("%s %s" % (REASONS[k], pct(v, len(rounds))) for k, v in sorted(why.items())))
        secs = np.array([r["seconds"] for r in rounds])
        fh = np.array([r["first_hit_time"] for r in rounds if r["first_hit_time"] >= 0])
        fr = np.array([r["first_hit_range"] for r in rounds if r["first_hit_range"] >= 0])
        w("- Round length: median %.0f s (10th %.0f, 90th %.0f); first hit at %.0f s median, from %.0f m\n" % (
            np.median(secs), np.percentile(secs, 10), np.percentile(secs, 90), np.median(fh), np.median(fr)))
        if any(r.get("overtime") for r in rounds):
            w("- Overtime flag went up in %s of rounds\n" % pct(sum(1 for r in rounds if r.get("overtime")), len(rounds)))
    if hits is not None and len(hits):
        rng = np.sqrt(((hits[:, 1:4] - hits[:, 4:7]) ** 2).sum(axis=1))
        w("- Knock-outs: %d. Range median %.0f m, 90th %.0f m, longest %.0f m; under 10 m %s, over 30 m %s\n" % (
            len(hits), np.median(rng), np.percentile(rng, 90), rng.max(), pct((rng < 10).sum(), len(rng)),
            pct((rng > 30).sum(), len(rng))))
        w("- Knock-outs scored by end: %s %s, %s %s\n" % (names[0], pct((hits[:, 0] == 0).sum(), len(hits)), names[1],
                                                        pct((hits[:, 0] == 1).sum(), len(hits))))
        by = defaultdict(lambda: [0, 0])
        for h in hits:
            by[field.area_of(h[4], h[5], h[6])][int(h[0])] += 1
        w("- Where people are hit (target's area: share of all, who scored end 0 / end 1):\n")
        for a, (e0, e1) in sorted(by.items(), key=lambda kv: -sum(kv[1]))[:14]:
            w("  - %-16s %5s   %d / %d\n" % (a, pct(e0 + e1, len(hits)), e0, e1))
        sh = defaultdict(int)
        for h in hits:
            sh[field.area_of(h[1], h[2], h[3])] += 1
        w("- Where shooters stand: %s\n" % ", ".join("%s %s" % (a, pct(n, len(hits))) for a, n in
                                                      sorted(sh.items(), key=lambda kv: -kv[1])[:10]))
    if stood is not None and len(stood):
        tr = defaultdict(lambda: [0, 0])
        for s in stood[::3]:
            tr[field.area_of(s[1], s[2], s[3])][int(s[0])] += 1
        tot = sum(sum(v) for v in tr.values())
        w("- Time spent (share of all player-seconds, end 0 / end 1 split):\n")
        for a, (e0, e1) in sorted(tr.items(), key=lambda kv: -sum(kv[1]))[:16]:
            w("  - %-16s %5s   %s / %s\n" % (a, pct(e0 + e1, tot), pct(e0, e0 + e1), pct(e1, e0 + e1)))
        quiet = [a for a in {x["name"] for x in field.d.get("areas", [])} if sum(tr.get(a, [0, 0])) < tot * 0.004]
        if quiet:
            w("- Hardly used (under 0.4 %% of player-seconds): %s\n" % ", ".join(sorted(quiet)))
    if survey:
        pts = np.array(survey["points"]).reshape(-1, 3)
        seen = np.array(survey["seen"], float)
        low = np.array(survey["seen_low"], float)
        lng = np.array(survey["longest"])
        w0, w1 = np.array(survey["walk0"]), np.array(survey["walk1"])
        n = len(pts)
        w("## %s survey: %d stand points every %.1f m\n" % (field.id, n, survey["step"]))
        k = int(np.argmax(lng))
        w("- Longest standing line %.0f m, from (%.0f, %.0f) in %s\n" % (lng[k], pts[k, 0], pts[k, 2],
                                                                        field.area_of(*pts[k])))
        areas = defaultdict(list)
        for i, p in enumerate(pts):
            areas[field.area_of(*p)].append(i)
        w("- By area: points | open to (%% of the points in sight range that see it standing / crouched) | longest "
          "line | walk from end 0 / end 1 (s at a run) | who gets there first\n")
        reach_n = np.maximum(1.0, np.array([((np.hypot(pts[:, 0] - p[0], pts[:, 2] - p[2]) <= survey["reach"]).sum() - 1)
                                            for p in pts]))
        rows = []
        for a, idx in areas.items():
            idx = np.array(idx)
            ok = (w0[idx] >= 0) & (w1[idx] >= 0)
            t0 = np.median(w0[idx][ok]) / RUN if ok.any() else float("nan")
            t1 = np.median(w1[idx][ok]) / RUN if ok.any() else float("nan")
            rows.append((a, len(idx), 100 * np.mean(seen[idx] / reach_n[idx]), 100 * np.mean(low[idx] / reach_n[idx]),
                         lng[idx].max(), t0, t1))
        for a, cnt, s, lo, lg, t0, t1 in sorted(rows, key=lambda r: (r[5] - r[6]) if not math.isnan(r[5]) else 0):
            first = "even" if abs(t0 - t1) < 1.5 else ("end 0 by %.0f s" % (t1 - t0) if t0 < t1 else "end 1 by %.0f s" % (t0 - t1))
            w("  - %-16s %4d | %4.1f / %4.1f | %3.0f m | %4.0f / %4.0f | %s\n" % (a, cnt, s, lo, lg, t0, t1, first))
        for k2, f in enumerate(field.d.get("flags", [])):
            d = np.hypot(pts[:, 0] - f["x"], pts[:, 2] - f["z"]) + 5 * np.abs(pts[:, 1] - f["y"])
            i = int(np.argmin(d))
            w("- Flag %s: end 0 %.0f s, end 1 %.0f s (%.2f times)\n" % ("AB"[k2], w0[i] / RUN, w1[i] / RUN,
                                                                         w0[i] / max(w1[i], 0.1)))
        ot = field.d.get("overtimeFlag")
        if ot:
            d = np.hypot(pts[:, 0] - ot["x"], pts[:, 2] - ot["z"]) + 5 * np.abs(pts[:, 1] - ot["y"])
            i = int(np.argmin(d))
            w("- Overtime flag: end 0 %.1f s, end 1 %.1f s\n" % (w0[i] / RUN, w1[i] / RUN))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("map")
    ap.add_argument("--out", required=True)
    ap.add_argument("--heat", nargs="*", default=[])
    ap.add_argument("--survey")
    ap.add_argument("--label", default="")
    ap.add_argument("--cell", type=float, default=1.0)
    args = ap.parse_args()
    os.makedirs(args.out, exist_ok=True)
    field = Field(args.map)
    name = field.d.get("name", args.map)
    tag = (" (" + args.label + ")") if args.label else ""
    stem = os.path.join(args.out, args.map + ("-" + args.label.replace(" ", "-") if args.label else ""))

    fig, axes, order = figure(field, "%s: plan%s. Dark = stops a standing eye, grey = crouch cover, brown = doors "
                              "(dark shut), orange / blue dots = spawns, yellow = flags, star = overtime flag" % (name, tag))
    for ax, st in zip(axes, order):
        draw_plan(field, ax, st)
    fig.tight_layout()
    fig.savefig(stem + "-plan.png", dpi=110)
    plt.close(fig)

    survey = None
    if args.survey:
        with open(args.survey) as f:
            survey = json.load(f)
        pts = np.array(survey["points"]).reshape(-1, 3)
        reach_n = np.maximum(1.0, np.array([((np.hypot(pts[:, 0] - p[0], pts[:, 2] - p[2]) <= survey["reach"]).sum() - 1)
                                            for p in pts]))
        st_of = np.array([field.storey_of(p[1]) for p in pts])
        sz = max(4.0, 26.0 * survey["step"] ** 2 * (108.0 / (field.x1 - field.x0)) ** 2)
        # exposure
        fig, axes, order = figure(field, "%s: how exposed each spot is%s. Red = seen from many places, blue = "
                                  "tucked away" % (name, tag))
        for ax, st in zip(axes, order):
            draw_plan(field, ax, st, faint=False)
            m = st_of == st
            v = np.array(survey["seen"], float)[m] / reach_n[m]
            ax.scatter(pts[m, 0], pts[m, 2], c=v, cmap="coolwarm", s=sz, marker="s", lw=0, alpha=0.8, zorder=4,
                       vmin=0, vmax=max(0.05, np.percentile(np.array(survey["seen"], float) / reach_n, 97)))
        fig.tight_layout()
        fig.savefig(stem + "-exposure.png", dpi=110)
        plt.close(fig)
        # longest line
        fig, axes, order = figure(field, "%s: longest clear line from each spot%s (m)" % (name, tag))
        for ax, st in zip(axes, order):
            draw_plan(field, ax, st)
            m = st_of == st
            sc = ax.scatter(pts[m, 0], pts[m, 2], c=np.array(survey["longest"])[m], cmap="viridis", s=sz, marker="s",
                            lw=0, alpha=0.85, zorder=4, vmin=0, vmax=survey["reach"])
        fig.colorbar(sc, ax=axes, shrink=0.6, label="m")
        fig.savefig(stem + "-lines.png", dpi=110, bbox_inches="tight")
        plt.close(fig)
        # who gets there first
        w0, w1 = np.array(survey["walk0"]), np.array(survey["walk1"])
        fig, axes, order = figure(field, "%s: who gets there first%s. Orange = end 0 sooner, blue = end 1 sooner "
                                  "(seconds at a run), white = both arrive together" % (name, tag))
        for ax, st in zip(axes, order):
            draw_plan(field, ax, st)
            m = (st_of == st) & (w0 >= 0) & (w1 >= 0)
            sc = ax.scatter(pts[m, 0], pts[m, 2], c=(w0[m] - w1[m]) / RUN, cmap="PuOr_r" if False else "coolwarm_r",
                            s=sz, marker="s", lw=0, alpha=0.85, zorder=4, vmin=-12, vmax=12)
        fig.colorbar(sc, ax=axes, shrink=0.6, label="end 1's lead (s)   <- end 0 first | end 1 first ->")
        fig.savefig(stem + "-first.png", dpi=110, bbox_inches="tight")
        plt.close(fig)

    with open(stem + "-report.md", "w") as out:
        if not args.heat and survey:
            report(field, None, None, [], {}, survey, out)
        for k, path in enumerate(args.heat):
            stood, hits, rounds, meta = load_heat([path])
            report(field, stood, hits, rounds, meta, survey if k == len(args.heat) - 1 else None, out)
            mode = "Attack / Defend" if meta["mode"] == "flag" else "Elimination"
            # traffic
            fig, axes, order = figure(field, "%s, %s: where bots spend the round%s. Orange = the %s end's players, "
                                      "blue = the %s end's" % (name, mode, tag, END_NAMES[field.id][0],
                                                               END_NAMES[field.id][1]))
            for e, cmap in ((0, "Oranges"), (1, "Blues")):
                layers = heat_layers(field, stood[stood[:, 0] == e], args.cell, (1, 2, 3))
                vmax = max(np.percentile(blur(l, 2)[l > 0], 97) if (l > 0).any() else 1 for l in layers)
                for ax, st in zip(axes, order):
                    if e == 0:
                        draw_plan(field, ax, st, faint=True)
                    show(field, ax, blur(layers[st], 2), cmap, vmax=vmax, alpha=0.6)
            fig.tight_layout()
            fig.savefig("%s-%s-traffic.png" % (stem, meta["mode"]), dpi=110)
            plt.close(fig)
            # hits
            fig, axes, order = figure(field, "%s, %s: where players are hit%s (red heat). Lines = the shot, from the "
                                      "shooter (dot, orange / blue by end) to the target" % (name, mode, tag))
            layers = heat_layers(field, hits, args.cell * 2, (4, 5, 6))
            vmax = max(np.percentile(blur(l, 1)[l > 0], 98) if (l > 0).any() else 1 for l in layers)
            for ax, st in zip(axes, order):
                draw_plan(field, ax, st, faint=True)
                show(field, ax, blur(layers[st], 1), "Reds", vmax=vmax, alpha=0.75)
                for h in hits[:: max(1, len(hits) // 500)]:
                    if field.storey_of(h[5]) != st and field.storey_of(h[2]) != st:
                        continue
                    ax.plot([h[1], h[4]], [h[3], h[6]], color=END_COLOURS[int(h[0])], lw=0.5, alpha=0.45, zorder=5)
                    ax.scatter([h[1]], [h[3]], s=4, color=END_COLOURS[int(h[0])], zorder=5, lw=0)
            fig.tight_layout()
            fig.savefig("%s-%s-hits.png" % (stem, meta["mode"]), dpi=110)
            plt.close(fig)
    print(open(stem + "-report.md").read())


if __name__ == "__main__":
    main()
