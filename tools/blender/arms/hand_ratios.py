"""Measure a hand's proportions in a picture and hold them against the owner's photo of a hand (HA1).

    python3 tools/blender/arms/hand_ratios.py <image> <wrist row> [mirror]

The picture shows one hand flat from its back, fingers up and the thumb to the right (`mirror` turns one with the
thumb on the left), on a clear or a plain light ground. `<wrist row>` is the picture's row of the wrist's crease. For
the model, `BL_REST=<folder> python3 -I tools/blender/arms/arms.py .` draws `rest_back.png`, whose wrist joint lies
on row REST_WRIST_ROW. Each ratio is printed beside the photo's (PHOTO) with how far off it is; the script fails
when any is more than LIMIT off.

How it measures: the fingertips are the four highest peaks of the outline; each web is the row where two fingers,
followed down from their tips, become one (fingers that touch leave a hole over the web, which counts); a finger's
length runs from its tip to its root, half way between its two webs, along the finger; the palm's width is the hand's
run just under the lowest web; the wrist's width its run on the wrist row.
"""
import sys

import numpy as np
from PIL import Image, ImageFilter

# The owner's photo (art/references/arms/hand-skin-photo.jpg in the project's files, a right hand from the back:
# wrist row 1290, mirrored), measured by this script.
PHOTO = {
    "hand length / palm width": 2.387,
    "middle finger / palm length": 0.677,
    "index finger / ring finger": 0.938,
    "little finger / middle finger": 0.663,
    "wrist width / palm width": 0.742,
    "middle finger's width / its length": 0.241,
    "index finger's width / palm width": 0.239,
}
# How far a ratio may lie from the photo's (share of it).
LIMIT = 0.10
# The wrist joint's row in preview.rest_hand's picture (REST_SIZE 1400 high).
REST_WRIST_ROW = 1183
# A texel is the hand's when it differs this much from the picture's ground (0 to 255), where no alpha says.
GROUND_OFF = 28
# Fingertips lie at least this far apart (share of the picture's width), in the picture's upper share TIP_ABOVE.
TIP_APART = 0.04
TIP_ABOVE = 0.6
# The outline's top edge is smoothed over this many columns before its peaks are taken.
TIP_SMOOTH = 9
# A run narrower than this share of the picture's width is one finger's, and is followed down its middle.
FINGER_RUN = 0.25
# A hole over a web: how far under where two fingers meet (a share of the picture's height) and how far to each
# side (pixels) it is looked for.
HOLE_UNDER = 0.08
HOLE_BESIDE = 15
# The palm's width is taken this far under the lowest web (share of the picture's height).
PALM_UNDER = 0.015
NAMES = ("pinky", "ring", "middle", "index")


def mask(path: str, mirror: bool) -> np.ndarray:
    """Where the picture shows the hand: by its alpha, or by its difference from the ground in its top corners."""
    im = Image.open(path)
    if im.mode == "RGBA":
        a = np.asarray(im)[:, :, 3] > 128
    else:
        g = np.asarray(im.convert("RGB")).astype(int)
        c = 12
        ground = np.median(np.concatenate([g[:c, :c].reshape(-1, 3), g[:c, -c:].reshape(-1, 3)]), axis=0)
        m = Image.fromarray(((np.abs(g - ground).max(axis=2) > GROUND_OFF) * 255).astype("uint8"))
        a = np.asarray(m.filter(ImageFilter.MedianFilter(7))) > 128
    return a[:, ::-1] if mirror else a


def run_at(a: np.ndarray, y: int, x: int) -> tuple:
    """The run of the hand on row `y` that holds or lies nearest column `x`: (first, last)."""
    xs = np.where(a[y])[0]
    runs = np.split(xs, np.where(np.diff(xs) > 1)[0] + 1)
    r = min(runs, key=lambda r: 0 if r[0] <= x <= r[-1] else min(abs(r[0] - x), abs(r[-1] - x)))
    return int(r[0]), int(r[-1])


def measure(path: str, wrist_y: int, mirror: bool) -> dict:
    """The ratios of the hand in the picture at `path`, by PHOTO's names."""
    a = mask(path, mirror)
    h, w = a.shape
    cols = np.where(a.any(axis=0))[0]
    top = np.full(w, h, dtype=int)
    for x in cols:
        top[x] = np.argmax(a[:, x])
    k = TIP_SMOOTH
    sm = np.convolve(top, np.ones(k) / k, mode="same")
    tips = []
    for x in range(cols[0] + k, cols[-1] - k):
        if sm[x] <= sm[x - k:x + k + 1].min() + 1e-6 and sm[x] < h * TIP_ABOVE:
            if not tips or x - tips[-1][0] > w * TIP_APART:
                tips.append((x, int(top[x])))
            elif top[x] < tips[-1][1]:
                tips[-1] = (x, int(top[x]))
    tips = sorted(sorted(tips, key=lambda t: t[1])[:4])
    # Each web: the row where two fingers' runs, followed down from their tips, become one; fingers that touch
    # leave a clear hole over the web, just under where they meet, which counts.
    runs = []
    for x, y in tips:
        rows = {}
        cx = x
        for yy in range(y, wrist_y):
            r = run_at(a, yy, cx)
            rows[yy] = r
            cx = min(max(cx, r[0]), r[1])
            if r[1] - r[0] < w * FINGER_RUN:
                cx = (r[0] + r[1]) // 2
        runs.append(rows)
    webs = []
    for i in range(3):
        left, right = runs[i], runs[i + 1]
        yb = next(yy for yy in range(max(tips[i][1], tips[i + 1][1]), wrist_y) if left[yy] == right[yy])
        xb = (left[yb - 1][1] + right[yb - 1][0]) // 2
        under = ~a[yb:yb + int(HOLE_UNDER * h), max(xb - HOLE_BESIDE, 0):xb + HOLE_BESIDE + 1]
        if under.any():
            yb += int(np.where(under.any(axis=1))[0].max())
        webs.append((xb, yb))
    # A finger's length: from its tip to its root, half way between its two webs (an outer finger's: between its
    # web and the hand's edge on that row), along the finger, so a finger spread wide measures as one held straight.
    length = {}
    for i, n in enumerate(NAMES):
        if i == 0:
            other = (run_at(a, webs[0][1] - 1, tips[0][0])[0], webs[0][1])
            root = ((other[0] + webs[0][0]) / 2.0, webs[0][1])
        elif i == 3:
            other = (run_at(a, webs[2][1] - 1, tips[3][0])[1], webs[2][1])
            root = ((other[0] + webs[2][0]) / 2.0, webs[2][1])
        else:
            root = ((webs[i - 1][0] + webs[i][0]) / 2.0, (webs[i - 1][1] + webs[i][1]) / 2.0)
        length[n] = float(np.hypot(tips[i][0] - root[0], tips[i][1] - root[1]))
    mid_x = tips[2][0]
    web_low = max(y for _, y in webs)
    p0, p1 = run_at(a, web_low + int(PALM_UNDER * h), mid_x)
    palm_w = p1 - p0 + 1
    w0, w1 = run_at(a, wrist_y, (p0 + p1) // 2)
    wrist_w = w1 - w0 + 1
    hand_len = wrist_y - tips[2][1]
    palm_len = wrist_y - (webs[1][1] + webs[2][1]) / 2
    widths = {}
    for i, n in enumerate(NAMES):
        y = int(tips[i][1] + length[n] * 0.5)
        f0, f1 = run_at(a, y, tips[i][0])
        widths[n] = f1 - f0 + 1
    return {
        "hand length / palm width": hand_len / palm_w,
        "middle finger / palm length": length["middle"] / palm_len,
        "index finger / ring finger": length["index"] / length["ring"],
        "little finger / middle finger": length["pinky"] / length["middle"],
        "wrist width / palm width": wrist_w / palm_w,
        "middle finger's width / its length": widths["middle"] / length["middle"],
        "index finger's width / palm width": widths["index"] / palm_w,
    }


def main(args: list) -> int:
    got = measure(args[0], int(args[1]), len(args) > 2)
    worst = 0.0
    for name, value in got.items():
        off = value / PHOTO[name] - 1.0
        worst = max(worst, abs(off))
        print("%-36s %.3f  photo %.3f  %+5.1f %%" % (name, value, PHOTO[name], 100.0 * off))
    print("worst %.1f %% (limit %.0f %%)" % (100.0 * worst, 100.0 * LIMIT))
    return 0 if worst <= LIMIT else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
