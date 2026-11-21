"""What a model's parts are made of (TQ1, SQ1): each face's kind goes out as its UV y (KIND_BASE + kind, UV x 0), and
the game's props' shader (game/play/look/look_surface.gdshaderinc, the same numbers) draws it: its shine, metalness
and fine pattern, for no triangles. A face of kind 0 (or a model with none) keeps the props' own roughness.

    write(ob, kind_of)   a UV map "Kinds" on `ob` from kind_of(material name); whether any face has a kind
    by_name(name)        a kind from a paint's name (works gear, stations: "galv", "glass", "rubber"...)

Dev tool: tools/ never ships.
"""

KIND_BASE = 100
GLOSS, STEEL, MOQUETTE, FLOOR, GLASS, RUBBER, ALUMINIUM, SATIN, LIT = 1, 2, 3, 4, 5, 6, 7, 8, 9
# 9 lit (TQ2): the street's daylight up Subway's entrance stair and its way-out sign, glowing by their own colour
# (look_vertex.gdshader).

# Paint-name words and their kind, the first found winning (a paint's own name, its "*shade" left off).
WORDS = (
    ("glass", GLASS), ("screen", GLASS), ("lens", GLASS), ("mask", GLASS),
    ("rubber", RUBBER), ("tyre", RUBBER), ("cable", RUBBER), ("hose", RUBBER), ("duct", RUBBER),
    ("galv", ALUMINIUM), ("alu", ALUMINIUM), ("booth_frame", ALUMINIUM),
    ("stainless", STEEL), ("chrome", STEEL), ("steel", STEEL), ("rail", STEEL), ("wheel", STEEL), ("pole", STEEL),
    ("gloss", GLOSS),
    ("cab_", SATIN), ("booth_white", SATIN), ("fan_panel", SATIN), ("satin", SATIN),
)


def by_name(name: str) -> int:
    """The kind a paint's name says, or 0."""
    own = name.split("*")[0].split(".")[0].lower()
    for word, kind in WORDS:
        if word in own:
            return kind
    return 0


def write(ob, kind_of) -> bool:
    """Writes each face's kind (kind_of(its material's name)) as its UV y; whether any face has one. glTF turns v
    over (1 - v), so Blender's v is 1 - (KIND_BASE + kind). A model with no kinds gets no UV map."""
    me = ob.data
    kinds = [kind_of(m.name) if m is not None else 0 for m in me.materials]
    if not any(kinds):
        return False
    layer = me.uv_layers.get("Kinds") or me.uv_layers.new(name="Kinds")
    me.uv_layers.active = layer
    uv = layer.data
    for p in me.polygons:
        k = kinds[p.material_index] if p.material_index < len(kinds) else 0
        v = 1.0 - (KIND_BASE + k)
        for li in p.loop_indices:
            uv[li].uv = (0.0, v)
    return True
