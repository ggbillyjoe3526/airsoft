# WF1 · Woodland faster with the same look: tree crowns' leaf cards trimmed to their leaves (Beta 2)

The owner, 21 November: "also can you try improve performance of woodlands map while keeping as much visual
detail/quality as possible? i love how it looks but i can fee the performance hit."

**Review:** REVIEW_LINE

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-21 | 1 | Opus 5.5 (build thread) | ✓ (touched tests; CI the rest) | CRITIC_1 | |

## Goal

Woodland's frame costs less on the GPU on every preset while every leaf draws where it did, near and far: no thinner
far crowns, no lost glow, no change to bounds, cover, collision or the layout. BP12 measured the WQ1 leaf cards at
about twice Beta 1's GPU time on Low; its two ready levers (far cards thinned, the leaves' glow and far fill off on Low)
each change the look, so neither is used here.

## Approach

- **The sheet's rectangles** (`tools/textures/leaf_trim.py`, `assets/textures/woodland/leaves_trim.tres`,
  `LeafTrimSheet`): for each card cell of the leaf sheet, the smallest rectangle holding every texel the foliage shader
  can draw from it at mip 6 or finer (its alpha read bilinearly at each level and grown by that level's cover, as
  `look_foliage.gdshader` grows it, a level more than its own), grown four sheet texels for the compression's alpha
  error. The crown cells' rectangles cover 0.40 to 0.80 of their cells; the needle-shoot row and the fern and hazel
  cells are near whole, and the masses and twigs (row 3) are drawn whole.
- **The trimmed crowns** (`LeafTrim`, `PropDressConfig.drawn_mesh_of`): each flat, axis-aligned card (two triangles
  sharing an edge) of a crown has its four corners moved in to its cell's rectangle, along its own plane, with the
  normals and colours read at the new corners. Each moved corner keeps the way back in CUSTOM0 (position) and CUSTOM1
  (UV, and the card's facing). Same triangles, same levels of detail (the importer's index lists reused), same
  material; an unused copy of each box-end corner the trim moved holds the box, so the packed positions and
  `get_aabb` stay the original's. The bark and
  solid cores move to the front of the index list so the depth prepass has them before the cards.
- **The shader opens a card back out** (`look_foliage.gdshader` `trim_open`): from the card's texels per pixel (its
  size on screen and how side-on it stands) it opens the corners out to the whole cell between mip 4.5 and 5, before
  the cut-out reads past mip 6, where the far fill's grown cover would reach past a rectangle. So a near card (most of
  a crown's fill) loses its empty margins and a far one draws as it always did. The shadow pass draws cards whole.
- **The dress** (`PropDress`) draws the trimmed meshes, sizes and wears them by the loaded mesh's box, and sets
  `trim_mip` from the sheet.

## Verified

- Pictures against main at three Woodland views on Low (software Vulkan, 960 x 540): differences over 8 levels on
  2.5 % of pixels, the shading's interpolation across the moved corners; sky seen through crowns within 0.2 %; a zoom
  on a far birch matches. Project files `art/woodland-wf1/`.
- GPU time a frame on Low, two rounds each, main against this branch (software Vulkan, relative only): at 960 x 540
  547 to 497 ms (track by the oak), 306 to 251 (under the pines by a thicket), 787 to 736 (long view); at 1920 x 1080
  835 to 764 and 1,492 to 1,381. The software renderer is bound by triangles more than fill, which this leaves alone;
  a real GPU's cost here is mostly the cut-out fill, so the gain there should be larger (N53).
- `tests/unit/test_wf1_leaf_trim.gd`: every drawn texel of the sheet at mips 2 to 6 lies in its cell's rectangle;
  each crown keeps its triangles, levels, box and material; every trimmed corner opens back to the model's own corner
  and lies in its rectangle; the oak's cards open along their planes; bark before cards; untrimmed models and no
  sheet drawn as loaded; the dress lays every model as before; the levels of detail draw solid faces first; a card sharing a corner
  with another face is kept whole. Touched tests; gdlint; wiki check.
- QA (`tests/unit/test_wf1_qa.gd`, 12 tests) passed; two of its notes are fixed here: a card whose corner another face
  also uses is no longer trimmed (the importer splits such corners, so no shipped crown had one), and the importer's
  levels of detail are put solid first like the main list. Performance passed: the five crowns trim in about 0.1 s
  once at load, 3.2 MB more memory, nothing a frame.

## Decisions

- **Spruces, ferns and bushes stay as they are.** The spruce tiers' kites aren't flat quads and their needle cells
  are near whole; the fern and hazel cells are near whole too. There is nothing to trim.
- **Shadows draw the cards whole.** The light's view has no screen mip to open by; trimming them there would need a
  shadow-texel measure of its own (a later lever, Medium and up only).
- **Thicket spruces' hidden lower tiers kept (considered, dropped).** Spruces deep in a thicket could lose their lower
  tiers, unseen from outside, but the outer spruces' cards have gaps, so the thicket would read thinner at eye height:
  a cover change.
- **BP12's two levers stay ready** (KNOWN_ISSUES): each changes the look on Low; the owner hasn't asked for either.

## Known issues left

- Frame rate on a real Low PC and on the owner's own preset: N53.
