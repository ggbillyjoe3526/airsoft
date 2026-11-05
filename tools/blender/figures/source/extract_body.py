"""Cut the figure body's anatomy out of the MakeHuman 1.x base mesh (hm08, CC0 1.0, makehumancommunity/makehuman):
the "body" group shaped as MakeHuman's young man (its default mix of the three male-young macro targets, a third each,
and a little of the muscular target), from the neck down, in metres, Blender axes (+Z up, the character facing -Y).
Writes a small OBJ with the joint centres as "# joint <name> x y z" lines.

Run once (the output is committed): python3 extract_body.py <base.obj> <targets dir> <out.obj>
base.obj is makehuman/data/3dobjs/base.obj; the targets are MPFB2's src/mpfb/data/targets/macrodetails/<name>.target.gz
(makehumancommunity/mpfb2, CC0 1.0), gunzipped into the targets dir. Fetched 2026-11-05 from makehuman master at
a8bc2d54ff0ac92e78ff71431b1023eda42bf482 and mpfb2 master at 6ff1eb358f6c1959ced77e79e6dd2406d9a71f49.
"""

import os
import sys

# The neck cut (m, MakeHuman space after conversion): everything above it is the head, which the headwear owns.
NECK_CUT = 0.62
# The targets and their weights: the young man of MakeHuman's default race mix, a fifth of the way to muscular.
TARGETS = {"caucasian-male-young": 1.0 / 3.0, "african-male-young": 1.0 / 3.0, "asian-male-young": 1.0 / 3.0,
           "universal-male-young-maxmuscle-averageweight": 0.2}


def main(src: str, targets: str, out: str) -> None:
    verts: list = []
    groups: dict = {}
    cur = None
    for line in open(src):
        if line.startswith("v "):
            verts.append([float(t) for t in line.split()[1:4]])
        elif line.startswith("g "):
            cur = line.split()[1]
            groups.setdefault(cur, [])
        elif line.startswith("f "):
            groups[cur].append([int(t.split("/")[0]) - 1 for t in line.split()[1:]])
    for name, w in TARGETS.items():
        for line in open(os.path.join(targets, name + ".target")):
            if line[:1].isdigit():
                i, x, y, z = line.split()
                v = verts[int(i)]
                verts[int(i)] = [v[0] + w * float(x), v[1] + w * float(y), v[2] + w * float(z)]

    def conv(v: list) -> tuple:
        return (v[0] * 0.1, -v[2] * 0.1, v[1] * 0.1)

    joints = {}
    for g, faces in groups.items():
        if g.startswith("joint-"):
            ids = {i for f in faces for i in f}
            c = [sum(verts[i][k] for i in ids) / len(ids) for k in range(3)]
            joints[g[6:]] = conv(c)
    body = [f for f in groups["body"] if all(conv(verts[i])[2] < NECK_CUT for i in f)]
    used = sorted({i for f in body for i in f})
    index = {o: n for n, o in enumerate(used)}
    with open(out, "w") as fo:
        fo.write("# The MakeHuman 1.x base mesh hm08 (CC0 1.0, makehumancommunity/makehuman), body group, young average\n")
        fo.write("# male target applied, cut below the head; metres, +Z up, facing -Y. Made by extract_body.py.\n")
        for k in sorted(joints):
            if "eye" in k or "lid" in k or "toe" in k or "tongue" in k or "jaw" in k:
                continue
            fo.write("# joint %s %.5f %.5f %.5f\n" % ((k,) + joints[k]))
        for i in used:
            fo.write("v %.5f %.5f %.5f\n" % conv(verts[i]))
        for f in body:
            fo.write("f " + " ".join(str(index[i] + 1) for i in f) + "\n")
    print("verts", len(used), "faces", len(body))


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2], sys.argv[3])
