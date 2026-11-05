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

## DT1 bolt-press fix (8753bef)

QA verdict: **Pass** (advisory items below, none blocking). Performance verdict: **Pass**. Read-only review; Godot was not run.

Change: BotCombat.shoot sets cmd.fire only when `not _bolt_cycling(a)` (replica().bolt_action and cooldown > 0). The check
sits before BotFireMode.pull in the `and` chain, so a held-back tick does not consume `next_tap` and the press is never
handed to Armament.step's bolt_press_window buffer (armament.gd:341-345). Root cause matches the diff.

QA
- Correct and narrow: only bolt-actions (the Sniper Rifle) are affected; AEG, pistols and Cyber take the old path (second test).
- `next_tap` is untouched while cycling (short-circuit); `burst_left` still ticks down, `pause_left` is set at burst end
  as before, so burst/pause bookkeeping is unchanged. `trigger_was_down` falls to false during the cycle, so the first
  tick with the bolt home is a fresh press (`not trigger_was_down` holds); it fires that same step (cooldown rests at 0 in semi).
- Cadence change (SN3 advisory, unmeasured): before, a click in the last 0.7 s of the 1.25 s cycle (fire_rate 0.8) fired
  the tick the bolt was home. Now the bot must be inside a burst window (skill.burst 0.2-0.45 s, then burst_pause
  0.3-0.65 s, personality-scaled) when the bolt comes home, else it waits for the next window. Sniper bots will fire
  somewhat slower than 0.8/s, by up to about one burst_pause, and Rushers (burst x1.2, pause x0.8) least. This is the
  safer direction and the SN3 target is unlikely to be broken, but no test pins the cadence; suggest a one-off
  shots-per-minute count for a Hard sniper bot over a fixed duel, and a PLAYTEST line.
- Other buffered presses past the line check, pre-existing and NOT fixed: (1) semi/burst `press_buffer` 0.15 s + fire_hold_off
  when a press lands during draw/reload busy (Sniper draw 0.65 s, reload 2.2 s) or cooldown > 0 on any semi replica
  (cooldown under 0.15 s, e.g. pistols at 7/s); (2) the window is 9 ticks, so a teammate needs about 1 m of movement
  in 0.15 s: very unlikely, not a measured failure. Note a bot that presses while reloading is possible only if shoot
  runs then; I did not trace whether the bot code stops pressing in reload/draw. Low risk, can wait; list in KNOWN_ISSUES if wanted.
- Tests: test_dt1_qa covers hold-during-cooldown and fire-when-home (stated to fail without the fix) and that an AEG is not
  held. Gaps: no assertion that next_tap or burst_left is unchanged, no test with a start_mode field (the `pull` semi-tap path).
- Restored stowed cooldown on weapon switch (armament.gd:448) is covered, as it sets `cooldown` too.

Performance
- Per shooting tick per bot: one `replica()` call (array index), two field reads, a compare. No allocation, no new
  node or resource, static function, `RefCounted` typed `var r`. BotCombat.bolt_waits already does the same lookup.
  On the held-back tick it also skips BotFireMode.pull. Net cost is below measurement; no budget affected.
- Fewer pressed-and-buffered events on Armament for sniper bots; no effect on the 60 Hz step budget.
