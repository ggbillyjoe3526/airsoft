Task: AB1 · head 04f599e · Verdict: Pass (attempt 3)
Run: no headless --perf match run (read review; test_two_flags.gd 14/14 pass) · budget: no baseline yet (perf-budget.json absent), judged against targets
Metrics: not measured; draw calls estimated (judgment) +~11/frame on Depot (second pole: 9 MeshInstance3D + Label3D outline+fill), ~+4 shadow casters per cascade

Blocking
- game/play/flag_view.gd:220-222 (judgment): the letter Label3D uses BILLBOARD_FIXED_Y and no `font`; the only Label3D in ShaderPrewarm is FigureView.make_sign (BILLBOARD_ENABLED, sign_font, game/play/figure_view.gd:272, play_session.gd:726). Label3D picks its shader by billboard mode, so the letter's variant is a missing prewarm: first sight of A/B on Depot compiles a shader mid-play. FlagView.materials() (flag_view.gd:116) returns only the cloth/ring materials.

Advisory
- game/play/flag_view.gd:38-47: each FlagView builds its own alu/dark/rope StandardMaterial3D + flat edge material; two poles = duplicates, not shared (judgment). Freed with the view (no leak).
- game/play/flag_view.gd:60-93: ~9 MeshInstance3D a pole (pre-existing pattern); second pole doubles it.
- game/sim/flag.gd:15-22,95: step_all runs at_pole (length() sqrt) per character per pole per tick; 2x of an already-cheap loop, no allocation. length_squared would drop the sqrt (judgment, minor).

Checked, clean (no per-tick/frame allocation)
- sim: Flag.step_all/rope_worked/highest/going_up/nearest (flag.gd:9-56) iterate typed arrays, only Vector2/float locals; RoundState.reset_flags (round_state.gd:61) only per round, keeps the array.
- bots: BotFlag.in_play once per tick (bot_controller.gd:272); post_of per defender think (bot_brain.gd:152, ternary is lazy so attackers skip it); no heap allocs. flag_pole re-pick (bot_movement.gd:139) fires on a pole change only; flag progress is monotone per pole and does not decay when idle, so no A/B flip-flop thrash.
- HUD: Hud.flag_shown/update (hud.gd:935,967) and play_session.gd:1098-1106 loops allocate nothing; HudFlagMarker.set_letter (hud_flag_marker.gd:147) early-outs on same letter (string compare only); warning text built only when the pole changes (hud.gd:1155) - `_warning_pole` is never reset, so it stays correct. `Flag.LETTERS[..]` is a const lookup.
- minimap: set_pole fills 2 preallocated slots (hud_minimap.gd:394), draw loops over _pole_count; no allocation.
- teardown: FlagView Label3D is a child of its pole, freed with it; views are children of the session, built once (play_session.gd:354, 692-700); no timers, tweens, or connections added. No orphans expected.
- Planner draws attack_flag once per round (round_planner.gd:42).

Fixes, ranked
1. Add the letter Label3D to the prewarm (FlagView exposes it, passed alongside the sign, or ShaderPrewarm gets a second sign), or set the letter to BILLBOARD_ENABLED to share the sign's variant.
2. Share the three pole materials across FlagViews (static or passed in).

Attempt 3 (395a152..04f599e): Pass. test_two_flags 17, test_bot_flag 14, test_flag_play 14 pass.
- bot_flag.gd pick_retakers/_pick_for: now runs every A/D tick (was only with the flag off the bottom), but costs O(retakers(2) x bots) a pole instead of the old O(defenders x bots) closer count, so a net cut when the flag is up and about 2 x bots x (role + is_in_play) extra at the bottom (judgment, ~tens of iterations/tick). Typed locals, `near: Bot` ref, no containers.
- pole_of/on_worked_rope (bot_flag.gd, bot_movement.gd FIGHT + _flag): per bot per tick, an index, a status check and one at_pole sqrt; no allocation.
- Flag.next_in_play (flag.gd:52) once a tick (bots) and once a frame (HUD _next_shown): one 2-flag loop, no allocation. Hud.shown_pole caches it; the Nearest fallback runs only with every flag at the bottom.
- Advisory unchanged: per-view pole materials, ~+11 draw calls on Depot.
