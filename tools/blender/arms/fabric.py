"""The arms' cloth surface (BL4): a small tiling normal map of a plain weave, laid over the glove, its moulded parts
and the sleeve at a set size in the world (the owner's glove photo 123404: stretch fabric over the back and fingers,
a fine texture on the moulded shell; the critic: no plain shading), so every surface reads as made, not as smooth
clay. The UVs are each arm's own, unwrapped by angle and scaled so one tile spans `TILE` metres everywhere."""

import math

import bpy
import numpy as np

SIZE = 256        # the map's side in pixels: one tile, `THREADS` threads each way
THREADS = 8
TILE = 0.008      # metres a tile spans on the arm: threads of 1 mm
# Each material's tile scale (threads finer or coarser) and how strongly its normal map bends the light.
WEAR = {"Glove": (1.0, 0.9), "GloveArmour": (0.6, 0.45), "Sleeve": (1.6, 0.8), "SleeveTrim": (1.3, 0.8)}


def weave_heights() -> np.ndarray:
    """One tile's height field (0..1) of a plain weave: warp threads along v, weft along u, each passing over and
    under the crossing threads in turn, rounded across their width and dipping where they go under."""
    t = (np.arange(SIZE) + 0.5) / SIZE * THREADS
    u, v = np.meshgrid(t, t, indexing="xy")
    iu, iv = np.floor(u), np.floor(v)
    fu, fv = u - iu, v - iv
    # Across a thread: a rounded profile, flat between threads.
    across_warp = np.clip(np.sin(math.pi * fu), 0.0, 1.0) ** 0.6
    across_weft = np.clip(np.sin(math.pi * fv), 0.0, 1.0) ** 0.6
    # Along a thread: over one crossing, under the next (a cosine through each cell, phase by parity).
    over = ((iu + iv) % 2.0) * 2.0 - 1.0
    warp = across_warp * (0.55 + 0.45 * over * np.cos(math.pi * (fv - 0.5)))
    weft = across_weft * (0.55 - 0.45 * over * np.cos(math.pi * (fu - 0.5)))
    return np.maximum(warp, weft)


def weave_image(name: str = "ArmsWeave") -> bpy.types.Image:
    """The weave as a tangent-space normal map image (packed, so the glTF carries it)."""
    img = bpy.data.images.get(name)
    if img is not None:
        return img
    h = weave_heights()
    # Periodic differences keep the tile seamless; the slope's scale sets how deep the threads look.
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * SIZE / THREADS * 0.35
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * SIZE / THREADS * 0.35
    n = np.stack([-dx, -dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    rgba = np.concatenate([n * 0.5 + 0.5, np.ones(h.shape + (1,))], axis=-1).astype(np.float32)
    img = bpy.data.images.new(name, SIZE, SIZE, alpha=False)
    img.colorspace_settings.name = "Non-Color"
    img.pixels.foreach_set(rgba.ravel())
    img.file_format = "PNG"
    img.pack()
    return img


def wear(img: bpy.types.Image) -> None:
    """Each cloth material takes the weave as its normal map, at its own strength."""
    for name, (_scale, strength) in WEAR.items():
        m = bpy.data.materials.get(name)
        if m is None:
            continue
        nt = m.node_tree
        tex = nt.nodes.new("ShaderNodeTexImage")
        tex.image = img
        tex.interpolation = "Linear"
        nm = nt.nodes.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = strength
        nt.links.new(tex.outputs["Color"], nm.inputs["Color"])
        nt.links.new(nm.outputs["Normal"], nt.nodes["Principled BSDF"].inputs["Normal"])


def unwrap(ob: bpy.types.Object) -> None:
    """UVs for `ob`: islands cut by angle, then scaled so one tile spans TILE metres (times its material's scale)."""
    for o in bpy.context.view_layer.objects:
        o.select_set(False)
    ob.select_set(True)
    bpy.context.view_layer.objects.active = ob
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_all(action="SELECT")
    bpy.ops.uv.smart_project(angle_limit=math.radians(60), island_margin=0.002, area_weight=0.0,
                             correct_aspect=True, scale_to_bounds=False)
    bpy.ops.object.mode_set(mode="OBJECT")
    me = ob.data
    uv = me.uv_layers.active.data
    area3, area2 = 0.0, 0.0
    for poly in me.polygons:
        area3 += poly.area
        pts = [uv[k].uv for k in poly.loop_indices]
        area2 += abs(sum(pts[i].x * pts[i - 1].y - pts[i - 1].x * pts[i].y for i in range(len(pts)))) * 0.5
    metres_per_uv = math.sqrt(area3 / max(area2, 1e-12))
    names = [s.material.name if s.material else "" for s in ob.material_slots]
    for poly in me.polygons:
        scale = WEAR.get(names[poly.material_index] if poly.material_index < len(names) else "", (1.0, 0.0))[0]
        k = metres_per_uv / (TILE * scale)
        for li in poly.loop_indices:
            uv[li].uv = uv[li].uv * k
