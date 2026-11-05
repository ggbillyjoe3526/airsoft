"""Cut the left arm (shoulder cap to fingertips) out of the MakeHuman base mesh; write a small OBJ in metres,
Blender axes (+Z up, character facing -Y), plus the arm's joint centres. Args: <base.obj> <out.obj>"""
import sys, math
src, out = sys.argv[1], sys.argv[2]
V = []; faces = []; groups = {}; cur = None
for line in open(src):
    if line.startswith('v '):
        V.append(tuple(map(float, line.split()[1:4])))
    elif line.startswith('g '):
        cur = line.split()[1]; groups.setdefault(cur, [])
    elif line.startswith('f '):
        f = [int(t.split('/')[0]) - 1 for t in line.split()[1:]]
        groups[cur].append(f)
def centre(g):
    s = {i for f in groups[g] for i in f}
    return [sum(V[i][k] for i in s) / len(s) for k in range(3)]
J = {g[8:]: centre(g) for g in groups if g.startswith('joint-l-')}
sh, el = J['shoulder'], J['elbow']
ax = [e - s for s, e in zip(sh, el)]; L = math.sqrt(sum(a * a for a in ax)); ax = [a / L for a in ax]
P = [s + a * 0.30 * L for s, a in zip(sh, ax)]
def keep(v):
    d = [a - b for a, b in zip(v, P)]
    t = sum(a * b for a, b in zip(d, ax))
    if t < 0 or v[0] < 0.8:
        return False
    if t < 0.75 * L:
        rad = math.sqrt(max(0.0, sum(a * a for a in d) - t * t))
        return rad < 0.75
    return True
body = groups['body']
sel = [f for f in body if all(keep(V[i]) for i in f)]
# largest connected component
par = {}
def find(a):
    while par.setdefault(a, a) != a:
        par[a] = par[par[a]]; a = par[a]
    return a
for f in sel:
    for i in f[1:]:
        ra, rb = find(f[0]), find(i)
        if ra != rb: par[ra] = rb
from collections import Counter
cnt = Counter(find(f[0]) for f in sel)
root = cnt.most_common(1)[0][0]
sel = [f for f in sel if find(f[0]) == root]
used = sorted({i for f in sel for i in f}); m = {o: n for n, o in enumerate(used)}
def conv(v):
    return (v[0] * 0.1, -v[2] * 0.1, v[1] * 0.1)
with open(out, 'w') as fo:
    fo.write('# The left arm of the MakeHuman 1.x base mesh (CC0 1.0, makehumancommunity/makehuman), cut at the\n')
    fo.write('# upper arm; metres, +Z up, facing -Y. Joint centres as "# joint <name> x y z".\n')
    for k in sorted(J):
        if any(s in k for s in ('shoulder', 'elbow', 'hand', 'finger')):
            fo.write('# joint %s %.5f %.5f %.5f\n' % ((k,) + conv(J[k])))
    for i in used:
        fo.write('v %.5f %.5f %.5f\n' % conv(V[i]))
    for f in sel:
        fo.write('f ' + ' '.join(str(m[i] + 1) for i in f) + '\n')
print('verts', len(used), 'faces', len(sel))
