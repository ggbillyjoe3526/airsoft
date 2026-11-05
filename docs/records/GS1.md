# GS1 · GBB Pistol: front sight when aimed, no gap in the port

**Review:** pending

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-05 | 1 | Claude (build thread) | gdlint, changelog, wiki, smoke, notices and the new test green locally; the four unit parts on CI | pending | – |

## What the owner asked (2026-11-05)

The front iron sight is not visible at all when aiming down sights; there is a gap between the slide and the barrel
in the ejection port.

## Causes

- **Sight.** Aimed, the eye sits on the `RearSight` empty's height (`ReplicaView`), which was the front post's top;
  the rear notch's floor was on that same line. From the eye the rear sight's body below the notch covered everything
  under the line, so the whole post (and its dot) hid behind it.
- **Port.** The barrel hood stopped 1 mm short of the port's front and back walls and 0.9 mm short of its left wall,
  with a 1.2 mm step at its back and rounded front corners, so a dark slit ran round it.

## What changed

All in `tools/blender/replicas/gbb.py`; `assets/models/replicas/pistol.glb` rebuilt from it. The parts file is
untouched (nothing it holds moved).

- **Sight picture.** `SIGHT_Z` (the post's top, both sight empties, so the eye aimed) rises from 1.8 to 3.0 mm above the
  slide, 0.4 mm under the rear sight's top (the photo's 3.4 mm) for an equal-height picture. The notch's floor sits
  `NOTCH_DROP` 2.1 mm under the line, so the whole post stands in the notch; the notch widens from 3.5 to 4.0 mm and
  the post narrows from 3.4 to 3.2 mm, leaving light either side. The post's white dot grows from 1 to 2 mm across and
  lies on the post's sloped back face. The notch's white U thins from 0.8 to 0.6 mm. The figures' copy follows.
- **Port.** The hood fills the port to a 0.15 mm hairline front, back and left (`HOOD_GAP`), its top flat and flush,
  its right face 1.2 mm inside the flank (`HOOD_INSET`) as the photos' chamber; its edges bevelled 0.25 mm instead of
  0.4 mm.
- 39,578 triangles in the hands (was 39,638; budget 40,000).

## Defaults taken

- The post stands 3.0 mm, taller than the main photo's 1.7 mm: a post the photo's height would have to sit at the
  notch's floor to show, too small to read at arm's length. Readability over the photo here (pillar 4).
- `aim_forward` (the pistol 0.36 m from the eye aimed) is unchanged: the post is about 7 px wide at 1080p, like a real
  pistol at arm's length. If it still reads too small in play, bringing the pistol closer is the next lever.

## Verified

- `tests/unit/test_pistol_sights.gd`: aimed, the ray from the eye to the post 1 mm under its top meets the post (not
  the rear sight) and rays 2.4 mm either side meet nothing (light in the notch); the post's top is on the sight line;
  no slit wider than 0.4 mm in the slide's top between the sights. All three pass on the new model; on the old one
  the eye test meets the rear sight (0.357 m) and the port has a 13.8 mm open run.

- Renders (Cycles, the game's 90 degree view zoomed 1.2 for the aimed view): before and after in
  `/mnt/project-files/art/blender/gbb-sight-port/`.
