Task: SN1 · The Sniper Rifle
Attempt: 1 of 4
Head: 7c5cca4 (checks passed on it)
Checks: 1 ✓ | 2 ✓ | 3 ✓ | 4 ✓ | 5 ✓ | 6 ✓ | 7 ✓ | 8 ✗
Score: 7/8 → Accept
Evidence for the passes (short):
1. Spring primary, AEG with a 0.20 m longer barrel (tools/blender/replicas/sniper.py, sniper.tres:9 power spring); single
   shot (sniper.tres:10 fire_modes [SEMI], 0.8/s, Fire clip + boltCycle after each shot sim_audio.gd:+216); 2x Scope
   fitted, removable and swappable (pool.md:+150 Comes with, loadout_rules.gd:+113, test_sniper_rifle.gd:78);
   M130/M140/M150 as the gases (stats.md:+85..87, pool.md:+162..164); levels 5/6/7/9, cap 10 (levels.md:+38..44);
   Sniper bot kit (bot-kits.md:+60); dev gating: pool Access dev, level-up card xp_card.gd:+130, wiki.py:+329, Roadmap
   "In development" only; Armory checked by QA (test_sn1_qa.gd:102,120).
2. No contract touched: game/ai and game/sim gain no Node, audio or input; new tuning is BotConfig/ReplicaConfig exports.
3. Hot paths read: accuracy.gd:+31 (one index and arithmetic), bot_combat.gd:+158/+185, sim_audio.gd:+216/+530 per
   SHOT event: no allocation. comes_with/_names allocate only at table read and loadout build.
4. test_sniper_rifle.gd:156 fails without Accuracy's hip term; :78 fails without Pool.comes_with/default_tune.
Failed checks, with evidence:
8. [judgment] The record's four "Known issues left" (docs/records/SN1.md:53-59: Loadout rounds 0.8 to "1 BBs/s",
   teammates carry the factory AEG, Dev-off level 7 bare in the Armory and on the level-up card, placeholder model)
   are not rows in docs/KNOWN_ISSUES.md, which docs/PROCESS.md:189 requires. And assets/audio/README.md, which lists
   every cue this game renders itself and its tool (whistle, ping, grenades, doors :14-33), has no boltCycle_1..3 /
   tools/render_bolt.gd entry (docs/ASSETS.md:+74 has it).
Must-fix (non-blocking, fold into this pull request before merge): add the four rows to docs/KNOWN_ISSUES.md (Class:
   can wait / document, Found 2026-11-02); add a boltCycle bullet to assets/audio/README.md with its re-render command.
Advisory (no check failed):
- game/ai/bot_brain.gd:114-115 repeats the mode test of :109-111; one shared `in_fight` bool would keep them in step.
- game/ui/settings_save_page.gd:642 counts dev items in "unlocked" with Dev content off (a number, never a name).
Owner should test in the game:
- Hold the trigger: one shot, and the cocking clip and sound line up with the 1.25 s before the next.
- Hip versus through the 2x Scope: does the 6x hip spread feel fair; is the flat reach to about 48 m right.
- Take the scope off, then fit a Red Dot; both survive a restart.
- Dev content off: Armory, Loadout, level-up at 5 and 7 show no sniper gear (level 7 is bare, known).
- Hard bots with the Sniper kit: do they wait too long for the sight, and are hip shots inside 8 m sensible.
- M140 and M150: the extra kick and slower cocking feel worth the energy.
