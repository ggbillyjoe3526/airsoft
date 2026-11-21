// A model painted in vertex colours (the CC0 props, the roof's steel), in the shared light (look_light.gdshaderinc).
// Its roughness and metalness per material; ALBEDO is the vertex colour as the model stores it, times `tint`: linear
// (a glTF's), or sRGB with `srgb_colours` (a mesh or MultiMesh built in code: Woodland's greybox, woods and bushes).
// With `paint_by_custom` (PropDress's MultiMeshes), each instance's custom data is a paint (linear) over the parts whose
// vertex alpha is 1; a part with alpha 0 (a container's bare steel, tools/blender/maps' kit.bare) keeps its colour.
// With `perforations` (PropDress's), a part whose UV x is over 1 (kit.perforated: x 2 plus metres across its row's
// middle, y metres along it) has a row of round holes punched down it, a crate's edge profiles' dense holes for no
// triangles; from far off, where a hole is under a pixel, they fade to the row's average shade so they never shimmer.
// A part whose UV x is under -1 (kit.ribbed: y metres across its ribs) is ribbed instead, fine grooves along it (an
// escalator step's cleats), fading to their average shade where a rib is under a pixel.
// With `wear` (SL2, docs/ART.md › Surfaces), times the look's `look_wear`, the model is worn in world space: grime up
// its foot (from its floor, `wear_floor` m up its own y: PropDress sets its box's bottom, where PropLayout stands it),
// streaks down its sides, broad stains, and dust settled on its tops, so no two props wear alike. Edge scuffs are the
// models' own paint (tools/blender). 0 (foliage, the greybox) is clean. With `use_sheet` (SM5, Subway's signs and
// posters: StationFixtures), the vertex colour is printed with `sheet` at the model's UVs.
shader_type spatial;
render_mode blend_mix, cull_back;

#include "res://game/play/look/look_vertex.gdshaderinc"
