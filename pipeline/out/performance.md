Task: DT1 (data tags) · head c39217f · Verdict: Pass
Run: none (owner asked for no Godot, tests or check.sh while another run is in progress); read-only review · budget: no baseline yet (pipeline/perf-budget.json absent), judged against targets and the SN1/SN2/BL5 records
Metrics: not measured. Node count, orphans, static memory and draw calls need a run; the owner's hardware gives frame times.
Regressions (> 10 % worse): none measured (judgment: no runtime code changed)

Scope (judgment): the diff changes no .gd or scene. It changes tags in data/pool.md (Sniper Rifle, M130/M140/M150, Variable Scope to public), data/maps.md (The Street to dev), one en.po string (PART_BLURB_SCOPEVAR), docs, changelog and tests. Two effects follow: the Sniper Rifle and Variable Scope are in ordinary matches, and the Street leaves them.

Blocking findings: none.

Checked, no cost found (judgment):
- Scope glass (game/play/optic_glass.gd:55,124-137): the SubViewport sits at UPDATE_DISABLED. It switches to UPDATE_ALWAYS only while a magnified optic's sight is raised and the model is visible, then back to DISABLED. The Variable Scope uses the same path as the already-public 2x Scope. At most one extra glass pass runs, for the local player, and bots never render one. The change adds no new cost class.
- Sniper model and sounds in ordinary matches: SN1 and BL5 record 36,054 triangles in the hands (budget 40,000), 7 materials, and bolt sounds rendered by tools/render_bolt.gd. A bot carrying the Sniper Rifle shows the same body mesh as the other bots' replicas. Loading is data-driven, once per match; no per-frame work and no new allocations.
- Bot kits (data/bot-kits.md): only a prose line changed. Bots already carried the Sniper Rifle with Dev content on, so the sim cost with it off matches the existing dev-on path.
- Customise/Armory pictures (game/ui/replica_pictures.gd:162,205,255): each SubViewport renders UPDATE_ONCE, then goes idle. Three optic pictures instead of two means one more single draw, once per page open or paint change, not per frame (judgment). Check that ReplicaPictures frees its ports on close; this predates the change and is not affected by it.
- Dropping The Street from the default catalogue lowers the load, since it is not built unless Dev content is on.
- en.po: one string, read at load; no cost.

Advisory:
- No rendered or --perf run was made; the shaders for the Variable Scope are the same as the 2x Scope's (judgment), so no prewarm entry looks needed. Confirm on the owner's hardware that the first raise of the Variable Scope does not hitch, which is the first time ordinary players meet it.
- With Sniper Rifle bots now public, several on Hard may hold long sight lines on open maps; the bot senses cost is existing code (bot_senses.gd) and was not re-measured.

Fixes: none needed.
