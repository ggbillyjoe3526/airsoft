# UG2 · Rooflight sun: the roof shades the sun but at its rooflights, with shafts in the haze

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | thread | see Checks | Retry 7/8 | the shade and lamps didn't cover the hall past 70 m from the eye; Sun shadows off still shaded |
| 2026-11-09 | 2 | thread | see Checks | pending | – |

## Goal

Step 2 of the owner's Ultra push for the whole game (2026-11-09, `docs/records/UG1.md` › Goal): an indoor field's
roof keeps the sun out except at its rooflights, so on Ultra the sun falls through them in strips and shows as shafts
in the volumetric haze, while the roof lamps (UG1) light the rest of the hall.

## Approach

- **A sun shade** (`RoofView._sun_shade`): one shadow-only mesh over the roof, slabs `shade_spans` wide, leaving a gap
  `RoofConfig.rooflight_half` (0.8 m) either side of each line halfway between two trusses, where the bay model's
  rooflight strips lie (`tools/blender/maps/roof_truss.py` › ROOFLIGHT). Over the ceiling slab, so it never shades
  the sheet itself; out of the bounce light, as the roof is. Built only with the bay model and lamps.
- **A thicker haze under the roof** (`RoofView._hall_haze`): a box FogVolume over the hall adding `shade_haze` (0.012)
  to the volumetric fog's density, so the shafts read; the map's own fog (0.006) is too thin indoors.
- **On Lamp light Far only** (Ultra): `RoofLamps.set_mode` shows both, the lamps shine `lamp_shaded_energy` (34)
  instead of 26, and `key_share` keeps the sun at `shade_sun_share` (1.0) instead of dimming it, only while the
  sun casts shadows: a shadow-only shade blocks nothing, so Custom with Sun shadows off falls back to Near's sun and
  lamps (QA).
- **The whole roof, from anywhere under it** (critic, attempt 1): shaded, every lamp is lit out to the roof's reach
  (its diagonal and height, about 133 m on Depot, past Far's usual 70 m) and `apply_field` stretches the sun's shadow
  distance so they reach it before their fade, so no part of the hall is shaded and unlit, or unshaded.
  Near and Off hide them, as before. Shared code: any roofed map with the bay model gets it.

## Defaults taken

- Far only, not High: Near lights only the lamps within 28 m, so with the sun shaded the hall past that would go dark.
- Lamp energy 34 and haze 0.012 from trial renders at Ultra: against UG1's Ultra (sun at 55 %, lamps 26, no shade),
  the same four cameras measure 94/95, 77/74, 87/80 and 118/104 in mean brightness (about 7 % brighter overall, the
  corner view most, with every lamp lit and the haze); walls right under a lamp brighter. Haze 0.02 washed out the
  hall's far end, against the 65 m sight line's readability.
- The rooflight panels themselves are drawn as before (opaque, lilac); a glowing rooflight is left for step 4.
- The sky's ambient light still reaches under the roof (the shade is out of the bounce light, as UG1 left the roof),
  so the shaded floor reads slightly blue; step 4's bounce-light work revisits it (`docs/KNOWN_ISSUES.md`).
- `RoofConfig.rooflight_half` copies `roof_truss.py`'s ROOFLIGHT (each says so); the gaps assume the bay is one truss
  step wide, as RoofView lays it.

## Checks

- gdlint clean; `test_sun_shade` 6/6 (spans, gaps on the rooflights, Far shows and Near hides, none with Sun shadows
  off, the lamps and sun shadows over the whole roof, no shade without the bay model) and QA's `test_sun_shade_qa` 3/3; `test_lamp_lights`, `test_lamp_lights_qa`, `test_depot_hall`, `test_graphics_apply`, `test_baked_light` pass.
- Before/after renders (Ultra, same cameras, Sunlit Concrete light; the fourth from one corner of the hall to the far
  one, even to the far end): `/mnt/project-files/art/graphics/ug2/`.

## Known issues left

- Frame cost on Ultra is unmeasured (no GPU in the cloud): the shade (one more caster for the sun's four splits), the
  haze volume, all 93 lamps lit and the sun's shadows stretched to about 166 m (coarser near splits). The owner's
  check is in the playtest list. The blue shade and missing purlin shadows: `docs/KNOWN_ISSUES.md`.
