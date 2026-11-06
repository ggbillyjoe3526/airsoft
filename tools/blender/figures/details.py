"""The figure body's raised details (BL10): pockets, flaps, cuffs, the collar, the waistband, the team armbands and the
gloves' hard parts, laid onto the garments built in body.py. Each returns {region: [(verts, faces), ...]}; the regions
are the body's paint regions (body.py REGIONS).
"""

import math

from mathutils import Vector

import garment as G


def _cast_out(surf: G.Surface, c: Vector, d: Vector) -> Vector:
    hit, _ = surf.cast(c, d.normalized(), 0.5)
    return hit if hit is not None else surf.nearest(c + d * 0.1)[0]


def _limb_side(head: Vector, tail: Vector, t: float, want: Vector) -> tuple:
    """A point on a limb's line (t of the way down it) and `want` made square to the line."""
    a = (tail - head).normalized()
    d = want - a * want.dot(a)
    return head.lerp(tail, t), a, d.normalized()


def pocket(surf: G.Surface, head: Vector, tail: Vector, t: float, want: Vector, h: float, w: float,
           flap: float = 0.32, puff: float = 0.010) -> dict:
    """A cargo pocket on a limb, `h` long down the limb and `w` across, centred t of the way down from head, on the
    side facing `want`; its flap covers the top `flap` of it, a size bigger and stiffer."""
    c, a, d = _limb_side(head, tail, t, want)
    centre = _cast_out(surf, c, d)
    across = a.cross(d).normalized()
    body = G.patch(surf, centre, a * h, across * w, 6, 6,
                   lambda u, v: 0.0016 + puff * G.soft_box(u, v, 0.22), inward=-d)
    fc = centre - a * h * (0.5 - flap * 0.5) - a * 0.004
    lid = G.patch(surf, fc, a * (h * flap), across * (w + 0.010), 2, 6,
                  lambda u, v: 0.0040 + puff * 1.1 * G.soft_box(0.5, v, 0.22) + 0.0030 * (1 - u), inward=-d)
    # The flap's press stud near its lower edge, domed over the flap.
    stud_at = 0.80
    top = 0.0035 + puff * 0.95 + 0.0025 * (1 - stud_at)
    stud = G.patch(surf, fc + a * (h * flap * (stud_at - 0.5)), a * 0.012, across.normalized() * 0.012, 2, 2,
                   lambda u, v: top + 0.0008 + 0.0018 * G.soft_box(u, v, 0.5), inward=-d)
    return {"pocket": [body, lid], "snap": [stud], "centre": centre, "frame": (a, across, d)}


def dorsal(r: dict, s: str) -> Vector:
    """The back of the hand's direction (away from the palm) on side s."""
    w = r["Hand_" + s][0]
    k = [r["%s1_%s" % (f, s)][0] for f in ("Index", "Middle", "Ring", "Pinky")]
    thumb = r["Thumb2_" + s][0]
    n = (k[0] - w).cross(k[3] - w).normalized()
    pc = (w + sum(k, Vector()) / 4.0) * 0.5
    return -n if (thumb - pc).dot(n) > 0 else n


def shirt(surf: G.Surface, r: dict, sleeve_end: float) -> dict:
    out = {"team": [], "pocket_shirt": [], "trim": []}
    for s, sx in (("L", 1.0), ("R", -1.0)):
        head, tail = r["UpperArm_" + s]
        length = (tail - head).length
        # The team armband round the upper arm (the owner's photos wear one there).
        out["team"].append(G.band(surf, head, tail - head, length * 0.50, length * 0.64, 0.0030, rows=2, cols=20))
        # The sleeve pocket on the shoulder, facing out and a little forward.
        p = pocket(surf, head, tail, 0.27, Vector((sx, -0.45, 0.25)), 0.085, 0.075, flap=0.36, puff=0.006)
        out["pocket_shirt"] += p["pocket"]
        out.setdefault("snap", []).extend(p["snap"])
        # The loop-velcro field for patches on the pocket's face, under the flap.
        a, across, d = p["frame"]
        out.setdefault("loop", []).append(G.patch(surf, p["centre"] + a * 0.016, a * 0.044, across * 0.056, 1, 2,
                                                  0.0016 + 0.006 + 0.0007, inward=-d))
        # The elbow pad's pocket on the back of the forearm's top.
        w = r["Hand_" + s][0]
        back = dorsal(r, s) + Vector((0.0, 0.6, 0.0))
        p = pocket(surf, tail, w, 0.14, back, 0.095, 0.080, flap=0.0, puff=0.005)
        out["pocket_shirt"].append(p["pocket"][0])
        # The cuff: a flat double layer with its velcro tab on the back of the wrist.
        up = (tail - w)
        out["trim"].append(G.band(surf, w, up, sleeve_end - 0.002, sleeve_end + 0.032, 0.0014, rows=1, cols=20))
        _, a, d = _limb_side(w, tail, 0.0, dorsal(r, s))
        c = _cast_out(surf, w + a * (sleeve_end + 0.018) - d * 0.02, d)
        across = a.cross(d).normalized()
        out["trim"].append(G.patch(surf, c, a * 0.024, across * 0.042, 1, 3,
                                   lambda u, v: 0.0030 + 0.0010 * (1.0 - v), inward=-d))
    return out


def trousers(surf: G.Surface, r: dict) -> dict:
    out = {"pocket": [], "trousers": []}
    for s, sx in (("L", 1.0), ("R", -1.0)):
        hip, knee = r["Thigh_" + s]
        k2, ankle = r["Shin_" + s]
        for p in (pocket(surf, hip, knee, 0.50, Vector((sx, -0.80, 0.0)), 0.190, 0.148, flap=0.30, puff=0.010),
                  pocket(surf, k2, ankle, 0.42, Vector((sx, -0.15, 0.0)), 0.095, 0.085, puff=0.008)):
            out["pocket"] += p["pocket"]
            out.setdefault("snap", []).extend(p["snap"])
        # The back pocket on the seat, under the yoke, with its flap and stud.
        p = pocket(surf, hip, knee, 0.09, Vector((sx * 0.35, 1.0, 0.0)), 0.120, 0.125, flap=0.34, puff=0.006)
        out["pocket"] += p["pocket"]
        out["snap"].extend(p["snap"])
    out["trousers"].append(G.band(surf, Vector((0.0, 0.0, 0.982)), Vector((0, 0, 1)), 0.0, 0.040, 0.0024,
                                  rows=2, cols=40))
    # Belt loops standing over the waistband, front, sides and back.
    for ang in BELT_LOOPS:
        d = Vector((math.sin(ang), -math.cos(ang), 0.0))
        c = _cast_out(surf, Vector((0.0, 0.0, 0.993)), d)
        out["trousers"].append(G.patch(surf, c, Vector((0.0, 0.0, 0.050)), d.cross(Vector((0, 0, 1))) * 0.013, 2, 1,
                                       lambda u, v: 0.0040 + 0.0008 * math.sin(math.pi * u), inward=-d))
    return out


BELT_LOOPS = (-0.45, 0.45, -1.45, 1.45, -2.45, 2.45, math.pi)   # angles round the waist from the front (rad)


def gloves(surf: G.Surface, r: dict) -> dict:
    """The gloves' hard parts (the owner's glove photos): a plate over the back of the hand and a moulded dome over each
    knuckle, padded finger guards, the palm's reinforcement and the wide strapped cuff."""
    out = {"glove_armour": [], "glove_palm": [], "glove_border": []}
    for s in ("L", "R"):
        w = r["Hand_" + s][0]
        k = [r["%s1_%s" % (f, s)][0] for f in ("Index", "Middle", "Ring", "Pinky")]
        fdir = (r["Middle1_" + s][0] - w).normalized()
        dors = dorsal(r, s)
        across = k[0] - k[3]
        mid = sum(k, Vector()) / 4.0
        c = _cast_out(surf, mid - dors * 0.02, dors)
        # The shell's fabric border, a size bigger than the shell and flat, then the shell: one moulded piece over the
        # back of the hand and the knuckle line, its edges rounded down into the border, a dome over each knuckle.
        out["glove_border"].append(G.patch(surf, c - fdir * 0.016, fdir * 0.060, across * 1.34, 3, 8,
                                           lambda u, v: 0.0010 + 0.0008 * G.soft_box(u, v, 0.3), inward=-dors))
        out["glove_armour"].append(G.patch(surf, c - fdir * 0.016, fdir * 0.048, across * 1.16, 6, 10,
                                           lambda u, v: 0.0012 + 0.0034 * G.soft_box(u, v, 0.45), inward=-dors))
        unit = across.normalized()
        for kk in k:
            kc = _cast_out(surf, kk - dors * 0.02, dors)
            out["glove_armour"].append(G.patch(surf, kc - fdir * 0.003, fdir * 0.021, unit * 0.0165, 3, 3,
                                               lambda u, v: 0.0035 + 0.0052 * G.soft_box(u, v, 0.5), inward=-dors))
        for f in ("Index", "Middle", "Ring", "Pinky"):
            for seg, frac in (("1", 0.62), ("2", 0.70)):
                key = "%s%s_%s" % (f, seg, s)
                if key not in r:
                    continue
                a, b = r[key]
                pc2 = _cast_out(surf, a.lerp(b, 0.5) - dors * 0.01, dors)
                out["glove_armour"].append(G.patch(surf, pc2, (b - a) * frac, across.normalized() * 0.014, 3, 3,
                                                   lambda u, v: 0.0005 + 0.0030 * G.soft_box(u, v, 0.5),
                                                   inward=-dors))
        # The palm's synthetic-suede reinforcement, heel of the hand to the base of the fingers.
        pm = _cast_out(surf, w.lerp(mid, 0.55) + dors * 0.02, -dors)
        out["glove_palm"].append(G.patch(surf, pm, fdir * 0.070, across * 1.05, 3, 6, 0.0010, inward=dors))
        # The wide elastic cuff and its strap round the wrist, up to the sleeve's end.
        up = r["UpperArm_" + s][1] - w
        out["glove_palm"].append(G.band(surf, w, up, 0.008, 0.050, 0.0022, rows=2, cols=18))
        # Its velcro strap, 3 cm wide, flat across the back of the wrist with a pull tab past its end.
        tc = _cast_out(surf, w + up.normalized() * 0.030 - dors * 0.02, dors)
        acr = up.normalized().cross(dors).normalized()
        out["glove_armour"].append(G.patch(surf, tc + acr * 0.006, up.normalized() * 0.028, acr * 0.058, 1, 4,
                                           lambda u, v: 0.0036 + 0.0004 * v, inward=-dors))
    return out


def zip_pull(z: float, y_top: float, y_bottom: float) -> tuple:
    """The collar zip's pull: a small tab hanging 2 cm from height z on the front of the collar, lying on its slope
    (y_top at its top, y_bottom at its foot; the collar faces -Y), wider at its foot."""
    w, h, t = 0.0050, 0.020, 0.0030
    vs = []
    for dz, y, wide in ((0.0, y_top, 1.0), (h, y_bottom, 1.4)):
        for dy in (0.0, t):
            for x in (-w * wide, w * wide):
                vs.append(Vector((x, y - dy, z - dz)))
    faces = [[0, 1, 3, 2], [4, 6, 7, 5], [0, 4, 5, 1], [2, 3, 7, 6], [0, 2, 6, 4], [1, 5, 7, 3]]
    return vs, faces
