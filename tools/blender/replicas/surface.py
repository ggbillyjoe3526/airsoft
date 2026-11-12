"""What a replica's, a part's or an accessory's faces are made of (MQ1, 2026-11-12; owner: "made out of metal
(steel/aluminium), polymer, wood").

The game paints a model's five scheme materials (Body, Furniture, Detail, Accent, Metal) in any paint, so a material's
name says which colour a face takes, not what it is made of: a rifle's receiver and its pistol grip are both Body.
Each face therefore also carries a surface kind, and the game draws the paint on that surface
(game/play/replica_surface.gdshaderinc, game/config/replica_surfaces.gd: steel and aluminium reflect under the paint,
polymer is matte and grained, wood shows its figure, `coated` is metal under a thick paint that keeps its colour in
any light, `bare` is bright unpainted metal). The kind rides in a colour attribute, `Surface`, written to the
glb as COLOR_0: white, so a material that multiplies by vertex colour draws as it did, with the kind in the alpha as
`index / SLOTS`.

A build script says the kinds while it builds, through material names, which every mesh operation keeps (bevels,
booleans, joins): a face built in the material `Body@polymer` is a Body-coloured face made of polymer.

    b.prism(outline, "x", -hw, hw, "Body@polymer")       # in a builder: an alias material, made when first named
    surface.tag(grip(), "polymer")                       # or a whole finished object, every material of it
    surface.tag(ob, "steel", only=("Detail",))           # or only some of its materials

    surface.resolve({"Body": "aluminium", "Metal": "steel"})   # then once, before the figures' copy is made

`resolve` writes the attribute on every mesh, a face with no kind of its own taking its material's from the table
(none where the table doesn't name it: plain white, alpha 1, which the game reads as "the part's usual kind"), and
folds the alias materials back into the ones they stand for, so the
file's materials are the ones it always had. `strip` takes the attribute off the figures' copies afterwards: they are
drawn in the plain paints, far off. `hardsurface.export` writes the attribute.

A part or an accessory (MQ2: an attachment, a magazine, a barrel) is simpler: each of its materials is one kind all
over, so its mesh carries no attribute (the parts files are near their size cap, and a colour a vertex is 8 bytes) but
a small table, material name to kind, as the mesh's custom property `surfaces`. The glb holds it as the mesh's extras,
Godot keeps those as the mesh's `extras` metadata, and the game reads the table there (ReplicaSurfaces.named).

    surface.name([part] + list(part.children_recursive), {"Detail": "aluminium", "Rubber": "rubber"})
"""

import bpy

# The kinds, by index: game/config/replica_surfaces.gd KINDS, in the same order (the files hold the index).
KINDS = ("polymer", "steel", "aluminium", "wood", "rubber", "bare", "coated", "polished")
SLOTS = 16
DEFAULT = "polymer"
ATTR = "Surface"
SEP = "@"
# The mesh custom property (the glb's mesh extras) a part's table of kinds rides in, and the figures' copies' suffix.
EXTRA = "surfaces"
FIGURE_SUFFIX = "_Figure"


def alias(base: str, kind: str) -> str:
    """The alias material's name for `base` made of `kind`."""
    if kind not in KINDS:
        raise ValueError("surface: no kind %r (one of %s)" % (kind, ", ".join(KINDS)))
    return "%s%s%s" % (base, SEP, kind)


def material(name: str) -> bpy.types.Material:
    """The material `name`; an alias (`Body@steel`) is made on first use as a copy of the one it stands for."""
    m = bpy.data.materials.get(name)
    if m is not None:
        return m
    if SEP not in name:
        raise KeyError("surface: no material %r" % name)
    base, kind = name.split(SEP, 1)
    alias(base, kind)
    m = bpy.data.materials[base].copy()
    m.name = name
    return m


def tag(ob: bpy.types.Object, kind: str, only: tuple = None) -> bpy.types.Object:
    """Every face of `ob` (or only those of the materials `only`) is made of `kind`. Returns `ob`."""
    me = ob.data
    for i, m in enumerate(me.materials):
        if m is None:
            continue
        base = m.name.split(SEP, 1)[0]
        if only is not None and base not in only:
            continue
        me.materials[i] = material(alias(base, kind))
    return ob


def tag_named(objects: list, table: dict) -> None:
    """Tags each of `objects` whose name is in `table`: a kind, or (kind, the materials it applies to)."""
    for ob in objects:
        entry = table.get(ob.name)
        if entry is None:
            continue
        if isinstance(entry, str):
            tag(ob, entry)
        else:
            tag(ob, entry[0], tuple(entry[1]))


def resolve(table: dict = None, default: str = None, objects: list = None) -> None:
    """Writes every mesh's `Surface` attribute and folds the alias materials back (see the module's docstring). A face
    whose material the table doesn't name (and `default` is None) says no kind: alpha 1, plain white, so a material
    the game leaves as the file has it (rubber, a lens, glass) draws exactly as it did, however clear it is."""
    table = table or {}
    for ob in (objects if objects is not None else bpy.data.objects):
        if ob.type != "MESH":
            continue
        me = ob.data
        if ATTR in me.color_attributes:
            me.color_attributes.remove(me.color_attributes[ATTR])
        layer = me.color_attributes.new(ATTR, "FLOAT_COLOR", "CORNER")
        slots = []
        for m in me.materials:
            name = m.name if m is not None else ""
            base, _, kind = name.partition(SEP)
            named = kind or table.get(base, default)
            slots.append((base, KINDS.index(named) if named else SLOTS, bool(kind)))
        # The slot each base material ends up in: its own if the mesh has one, else its first alias's (renamed).
        home = {}
        for i, (base, _, aliased) in enumerate(slots):
            if base and not aliased:
                home.setdefault(base, i)
        for i, (base, _, _) in enumerate(slots):
            if base:
                home.setdefault(base, i)
        values = [0.0] * (len(me.loops) * 4)
        for p in me.polygons:
            known = p.material_index < len(slots)
            base, k, _ = slots[p.material_index] if known else ("", SLOTS, False)
            a = k / SLOTS
            for li in p.loop_indices:
                values[li * 4:li * 4 + 4] = (1.0, 1.0, 1.0, a)
            if base:
                p.material_index = home[base]
        layer.data.foreach_set("color", values)
        me.color_attributes.active_color = layer
        me.color_attributes.render_color_index = list(me.color_attributes).index(layer)
        for base, i in home.items():
            me.materials[i] = bpy.data.materials[base]
        # Drop the folded alias slots, last first so the indices before them hold.
        keep = set(home.values())
        for i in range(len(slots) - 1, -1, -1):
            if slots[i][2] and i not in keep:
                _pop_slot(me, i)
    for m in list(bpy.data.materials):
        if SEP in m.name and m.users == 0:
            bpy.data.materials.remove(m)


def _pop_slot(me: bpy.types.Mesh, index: int) -> None:
    """Removes material slot `index` of `me` (Blender moves the faces of later slots down with them)."""
    me.materials.pop(index=index)


def strip(prefix: str = "Figure", suffix: str = "_Figure") -> None:
    """Takes the attribute off the figures' copies (meshes named `Figure*` or `*_Figure`)."""
    for ob in bpy.data.objects:
        if ob.type == "MESH" and (ob.name.startswith(prefix) or ob.name.endswith(suffix)):
            if ATTR in ob.data.color_attributes:
                ob.data.color_attributes.remove(ob.data.color_attributes[ATTR])


def kinds_of(ob: bpy.types.Object) -> dict:
    """How many triangles of `ob` are each kind, by name (for a build's printout and its checks)."""
    me = ob.data
    out = {}
    if ATTR not in me.color_attributes:
        return out
    data = me.color_attributes[ATTR].data
    for p in me.polygons:
        i = int(round(data[p.loop_indices[0]].color[3] * SLOTS))
        k = KINDS[i] if i < len(KINDS) else "none"
        out[k] = out.get(k, 0) + len(p.vertices) - 2
    return out


def adopt() -> None:
    """A mesh read back from a glb (a parts file a script moves and writes again) has its kinds in the importer's
    colour attribute: named `Surface` again, so the export writes it."""
    for me in bpy.data.meshes:
        if ATTR in me.color_attributes or len(me.color_attributes) != 1:
            continue
        me.color_attributes[0].name = ATTR


def name(objects: list, table: dict) -> None:
    """Says what each material of a part's meshes is made of, a whole material one kind (see the module's docstring):
    the mesh's `surfaces` table, holding only the materials the mesh has and the table names. The figures' copies
    (`*_Figure`) are left out: they are drawn in the plain paints."""
    for ob in objects:
        if ob.type != "MESH" or ob.name.endswith(FIGURE_SUFFIX):
            continue
        named = {m.name: table[m.name] for m in ob.data.materials if m is not None and m.name in table}
        for kind in named.values():
            if kind not in KINDS:
                raise SystemExit("%s: no surface kind '%s'" % (ob.name, kind))
        if EXTRA in ob.data:
            del ob.data[EXTRA]
        if named:
            ob.data[EXTRA] = named


def only_tables() -> None:
    """Lets go of every custom property but the meshes' tables before a file is written: the exporter writes each one
    as glTF extras (hardsurface.export), and the tables are all the game reads."""
    blocks = list(bpy.data.objects) + list(bpy.data.meshes) + list(bpy.data.materials) + list(bpy.data.scenes)
    for block in blocks:
        for key in list(block.keys()):
            if not (key == EXTRA and isinstance(block, bpy.types.Mesh)):
                del block[key]


def named(ob: bpy.types.Object) -> dict:
    """A part's table of kinds as `name` wrote it (or as a glb read back holds it), material name to kind."""
    table = ob.data.get(EXTRA) if ob.type == "MESH" else None
    return dict(table.items()) if table is not None else {}
