# MQ4 · Metal and polymer evened to a close shade

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-15 | 1 | Opus 5.5 (metal and polymer thread) | pending | pending | – |

## What changed

Owner, 2026-11-15: "materials on guns clash too much. Metal is too shiny and the polymer is relatively very dark.
Materials should generally be a close or similar shade but appear slightly more metallic (metals) or matte
(polymer)." On the before and after pictures (/mnt/project-files/art/model-quality/mq4/): "Perfect".

MQ1 drew coated steel and aluminium at 80 to 85 % metallic with a tight highlight and a gunmetal floor (0.1 linear),
so a black slide or receiver mirrored the room as a silver grey, while polymer drew its paint at 72 % with a very
dull highlight, nearly black. Only the surface table changes (`ReplicaSurfaces.LOOKS`, presentation only):

| Kind | metallic | roughness | gain | floor | specular |
|---|---|---|---|---|---|
| polymer | 0 | 0.66 → 0.6 | 0.72 → 0.9 | – | 0.25 → 0.4 |
| steel | 0.8 → 0.4 | 0.36 → 0.48 | 0.64 → 1.0 | 0.1 → 0.035 | 1.0 → 0.5 |
| aluminium | 0.85 → 0.45 | 0.3 → 0.45 | 0.68 → 1.0 | 0.12 → 0.04 | 1.0 → 0.5 |

Metal is now a satin coat with a broad soft highlight, near black in a black paint, and polymer is a matte dark grey
beside it. Every replica in the hands, every attachment, magazine and barrel, the power sources and grenades take it
(they share the table). Bare and polished metal (a bolt in its port, a brass crown), rubber, card and the Cyber's
coated slab are unchanged. The menus' pictures (Loadout, Customise, the part cards, the Armory) are drawn live from
the models with the same materials, so they follow with nothing baked to redo (owner, 07:15: "This should also apply
to models for attachments and accessories. Make sure all in game images are updated too"; pictures 4 to 6 show both).

- `tools/render_fp.gd` (dev tool): `preset:`, `map:` and `spot:` arguments and a `:paint=` per shot, for the Low and
  Ultra pictures.
- Tests (`test_replica_surfaces.gd`): metal and polymer gains within 0.15 of each other, metal at most 0.6 metallic
  with a floor of at most 0.05, polymer's gain at least 0.85 and under 1 (white polymer still off-white), metal still
  the smoother.

## Decisions

- **Bots' copies unchanged** (default): they wear ReplicaPaint's flat paints, where only the `Metal` part is a little
  metallic (0.4) and the rest is matte; the studio pictures show metal and polymer already a close shade there.
- **Replaces MQ1's shade ruling** (owner): "black polymer darker but not as dark as the black metals" gave way to
  the close shade; white polymer stays a touch off-white (gain under 1) and no replica is wood.
