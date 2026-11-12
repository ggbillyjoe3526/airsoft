Task: MQ1 · Replicas made of steel, aluminium, polymer and wood
Attempt: 1 of 4
Head: 4ae2546 (checks passed on it; matches `git rev-parse HEAD`)
Checks: 1 ✗ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✗ | 8 ✓
Score: 6/8 → Retry (judgment; not a near miss, blocking check 1 fails)

Failed checks, with evidence (each one judgment):

1. [judgment] The models rule applies because all five .glb files changed. Parts (a) and (c) pass. Parts (b) and (d) fail on the renders.
   - (a) I measured before and after on the same angle: overall length, handguard, magazine drop, stock and slide. All are within 1 % (AEG 904/906 px, handguard 218/220 px). No owner reference photo was in the brief, so proportions are only checked against the approved shapes.
   - (d) bar, AEG/SMG/Sniper/Cyber: in 01, 03, 04 and 05 the BEFORE and AFTER pictures are almost the same. The Cobalt AEG handguard and the sniper rail are tagged aluminium, but they read as the same flat blue plastic. There is no sharp highlight on the rail edges or the barrel and no anodised sheen. The Tan AEG handguard and stock read as cream plastic. The SMG's "steel receiver" is the old flat black. This is not AAA work and does not meet "more realistic detail and surfaces". Cause: metallic 0.7–0.75 with roughness 0.44–0.52 and relief 0.07–0.16 is too soft to show (game/config/replica_surfaces.gd:42-50). The paint is the metal's albedo, so a coated part shines like coloured chrome or not at all, never like a clear coat over metal (game/play/replica_surface.gdshaderinc:+442-445).
   - (b) GBB slide (02): stretch 10 on the side projection smears the brushed grain over the serrations. The close-up shows streaked, stretched texels and scratch lines that cut through the serration faces (replica_surface.gdshaderinc:+413-414, replica_surfaces.gd:44).
   - (d) GBB realism: a real coated slide is matte nitride or cerakote, not brushed stainless. The Ghost (white) slide turns silver, so the paint's colour is lost on the part players see most. In Tan, slide and frame read as one material.
   - (d) Sniper: in Tan the barrel is tan-painted metal. The owner said "barrel is metal", which should read as dark steel in any paint. The wood option (not shipped) is evenly spaced straight stripes, like a decal: no cathedral figure, no pores, no varying ring width. The cheek insert keeps the paint's colour on the wood.

7. [judgment] Names that no longer read:
   - `_worn`, `worn_materials()` and `apply(..., worn)` now mean "surfaced", worn or not (game/play/replica_paint.gd:+186, +198, +298).
   - `OWN_GLOW := 1.0` multiplies by one and does nothing (replica_paint.gd:+177).
   - `z_clip_scale` is declared in the middle of the kind tables (replica_surface.gdshaderinc:+349).
   - The grain texture is imported Lossless, not VRAM compressed (replica_grain.png.import:18). That needs a written reason.

Other items:
- The committed pipeline/out/performance.md at head is SM5B's. MQ1's report exists only as an uncommitted edit, so commit it with the records.
- qa-report.md still says "QA commit PENDING".
- The wiki line "The AEG Rifle and the GBB Pistol look lightly used" (docs/wiki/Replicas.md, the hunk at +114) contradicts CC0_ASSETS.md, which now says the Compact SMG wears too.

Must-fix for the next attempt:
- Make the metal read as metal. Draw coated steel and aluminium as a clear coat over metal: dielectric paint colour plus a tight metal specular lobe, a lower roughness (about 0.25–0.35), and a strong highlight on edges and rails. Hit a visible difference in every BEFORE/AFTER pair.
- Give the Glock-style slide a matte coated finish in the paint's colour instead of brushed silver. Keep brushing for bare parts only, and kill the stretch smear on faces across the bore.
- Keep steel barrels dark steel in any paint.
- Give the wood real figure: irregular ring spacing, pores, a cathedral pattern on the flats. Leave the cheek insert unpainted or make it wood.
- Re-render the same six sheets and judge each pair side by side. Then rename `_worn` and its family and fix the import and the stale wiki line.

Owner should test in the game:
1. AEG (Cobalt, Tan) at inspect in the Depot and Subway: do the receiver and handguard read as metal and the grip as plastic?
2. GBB Ghost and Tan: is a silver or brushed slide what you want, or a coated slide in the paint's colour?
3. Close to a wall and aiming down sights: any grain shimmer or crawling on the slide and handguard?
4. Sniper in Tan: is a tan barrel acceptable? Is wood or polymer the stock you want?
5. Customise pictures and turntable: do the metal reflections look like a studio or like grey plastic?
6. First equip of each replica: any hitch (shader prewarm)?
