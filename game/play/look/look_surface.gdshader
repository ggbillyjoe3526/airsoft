// A Woodland structure or prop (WQ1): look_vertex.gdshader's model in vertex colours, each face also drawn with its
// surface's detail and relief (sawn wood, log bark, sawn ends, concrete, galvanised steel, earth, moss): the layer
// mapkit.SURFACES gave it (UV2 x) of assets/textures/woodland/surfaces.png, at its UVs. Its UVs are the surfaces', so
// it draws no perforations or ribs.
shader_type spatial;
render_mode blend_mix, cull_back;

#define LOOK_SURFACES
#include "res://game/play/look/look_vertex.gdshaderinc"
