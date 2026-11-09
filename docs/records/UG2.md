# UG2 · Rooflight sun: the roof shades the sun but at its rooflights, with shafts in the haze

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-09 | 1 | thread | see Checks | pending | – |

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
  instead of 26, and `key_share` keeps the sun at `shade_sun_share` (1.0) instead of dimming it. Near and Off
  hide them, as before. Shared code: any roofed map with the bay model gets it.

## Defaults taken

- Far only, not High: Near lights only the lamps within 28 m, so with the sun shaded the hall past that would go dark.
- Lamp energy 34 and haze 0.012 from twelve trial renders at Ultra: the floor at eye height within about 5 % of the
  lamps-Off brightness (94 against 99, 77 against 80), walls right under a lamp brighter; haze 0.02 washed out the
  hall's far end, against the 65 m sight line's readability.
- The rooflight panels themselves are drawn as before (opaque, lilac); a glowing rooflight is left for step 4.
- The sky's ambient light still reaches under the roof (the shade is out of the bounce light, as UG1 left the roof),
  so the shaded floor reads slightly blue; step 4's bounce-light work revisits it.

## Checks

- gdlint clean; `test_sun_shade` 4/4 (spans, gaps on the rooflights, Far shows and Near hides, no shade without the bay
  model); `test_lamp_lights`, `test_lamp_lights_qa`, `test_depot_hall`, `test_graphics_apply`, `test_baked_light` pass.
- Before/after renders (Ultra, same cameras, Sunlit Concrete light): `/mnt/project-files/art/graphics/ug2/`.

## Known issues left

- Frame cost of the shade (one more shadow caster for the sun's four splits) and the haze volume on Ultra is
  unmeasured (no GPU in the cloud); the owner's check is in the playtest list.
