# RP1 · Every replica and part its own job

**Review:** 2 attempts · critic Accept 8/8 · qa Pass · performance Pass

## Attempts

| Date | Attempt | Worker model | checks | Critic | Retry reason |
|---|---|---|---|---|---|
| 2026-11-12 | 1 | build thread | ✓ 5,942 of 5,944 (2 pending) | 7/8 Retry | The Red Dot was still a straight upgrade (the trade-off test exempted it) |
| 2026-11-12 | 2 | build thread | ✓ 5,957 of 5,959 (2 pending) | 8/8 Accept | – |

The owner's balance pass of the replica half (2026-11-12): "look at all the replicas and their attachments. Make sure
each weapon has its own strengths and weaknesses. Each weapon should feel unique and attachments should offer
incentives to use while also feeling unique from each other. Feel free to make any changes to the specs of replicas
or attachments. Also look at accessories like gasses, batteries, grips, etc." And, on seeing the first table the same
hour: "Springs should have differences." No task block (asked for directly; the
maps half is another thread's). No new models, sounds or animations; the first-person arms are untouched.

## What was wrong

Measured on `data/stats.md` as it stood, with the game's own flight (`Ballistics.hop_up_reach`, the 15 cm band) and
spread (`Accuracy`):

- **The Cyber Pistol had no weakness.** 1.0 J against the AEG Rifle's 0.97, 0.3° against 0.45°, 14 BBs a second
  against 13, a quicker draw and reload, and running from the hip 0.78° against the Compact SMG's 0.81°: it beat the
  rifle standing and the SMG at the SMG's own job. Next to the GBB Pistol it was at least as good at everything.
- **The GBB Pistol had no job.** Its draw (0.30 s) was the Compact SMG's (0.32 s), with a rifle allowed in the sidearm
  slot.
- **Parts that were no choice.** The Red Laser tightened every shot by a fifth at no cost. The Vertical Grip paid a
  quarter more handling for 0.1 s less shake. The Long Barrel gave energy and nearly the Tight-Bore's groups, so the
  two overlapped. The LiPo's and the gases' kick (10 % of 0.18° and 0.5°) could not be felt. The Hi-Cap's only cost
  was a rattle heard at a walk. The springs were one ladder: 10 % energy and kick and 5 % of the cycle a step.

## What each is for now

| Replica | Leads at | Pays with |
|---|---|---|
| AEG Rifle | The all-rounder: the most BBs (240), every part slot | Best at nothing else |
| GBB Pistol | The quickest to hand (0.22 s), tight for a pistol, tighter from the hip, gas sets its reach | Single shots, the hardest kick, 18 BBs |
| Cyber Pistol | The owner's design: rifle power, the tightest automatic, almost no kick, pistol handling | 90 BBs a round, twice the run's spread, no parts |
| Sniper Rifle | Reach (48 m) and the tightest spread | One shot, the slowest on its feet (×0.95), ten times as wide from the hip |
| Compact SMG | The fastest fire, the tightest and quickest on the move (as approved in CS1) | The shortest reach of the rifles, few parts |

| Before | After |
|---|---|
| GBB Pistol: reload 1.2 s, draw 0.30 s, spread 0.8°, hip ×1, pace ×1 | 1.0 s, 0.22 s, 0.65°, ×0.8, ×1.04 |
| Cyber Pistol: 50 × 3 BBs, moving spread ×1, pace ×1 | 30 × 3, ×2, ×1.04 (energy, rate, spread, kick, draw and reload as they were) |
| Sniper Rifle: pace ×1 | ×0.95 |
| 11.1 V LiPo: recoil +10 % | +30 % |
| Red Gas: recoil +10 % | +20 % |
| Black Gas: recoil +20 %, fire rate as it comes | +40 %, −10 % |
| M130 Spring: as the rifle comes | heard from −15 % (the quick, quiet one) |
| M140 Spring: energy +10 %, fire rate −5 %, recoil +10 % | +10 %, −5 %, +20 % (the middle one) |
| M150 Spring: energy +20 %, fire rate −10 %, recoil +20 % | +20 %, −10 %, +50 %, heard from +20 % (the long shot) |
| 2x Scope raise ×1.6, Variable Scope ×1.9 | ×1.45, ×2; draw ×1.1 and ×1.15 (a new column) |
| Red Dot: no cost | draw ×1.1 |
| Vertical Grip: handling ×1.25, shake ×0.6 | ×1.15, ×0.6, moving spread ×0.8 |
| Angled Grip: handling ×0.8, shake ×1.3 | ×0.85, ×1.4 |
| Red Laser: spread ×0.8 | hip spread ×0.75, handling ×1.05 |
| Tight-Bore Barrel: spread ×0.85 | ×0.8 |
| Long Barrel: spread ×0.9, handling ×1.15 | ×1 (none), ×1.1 |
| Hi-Cap Magazine: reload ×1 | ×1.25 |
| Low-Cap Magazine: reload ×0.75, draw ×0.9 | ×0.7, ×0.85 |

The AEG Rifle, the Compact SMG, the Silencer, the Extended Magazine and the torch keep their numbers.

## The code

- `PartStats`: the Grips table reads **Moving spread (×)**; the Lasers table reads **Hip spread (×)** and
  **Handling (×)** in place of Spread (×); the Optics table reads **Draw (×)**.
- `ReplicaStats`: the Power sources table reads **Heard from %** (a table without the column reads as 0, quietly);
  `LoadoutRules.carried` lays it over the muzzle part's `heard_scale`, which the bots' hearing, the minimap, the sound
  cues and the shot's reach already read. Customise's power cards show the figure where a source that fits changes it
  (the springs).
- `LoadoutRules._apply_parts`: a grip's moving spread and a laser's hip spread multiply the replica's own
  (`ReplicaConfig.move_spread`, `hip_spread`, which `Accuracy` already reads), and a laser's handling joins the
  grip's, barrel's and muzzle part's on the draw and the raise; an optic's draw multiplies the draw time beside the
  magazine's. Run once when a kit is built, never per tick.
- `PartOptions`: the laser card shows "from the hip" and, like a barrel's, its aim in when a part changes it; a grip
  card adds "moving 80 %" when the grip changes it (no-break spaces keep the figure whole when the line wraps); an
  optic card adds its draw. Seven new words in `en.po`.
- `tools/wiki.py`: the Replicas table has a Pace row.
- `tests/unit/test_rp1_balance.gd` holds the rules as invariants, read from the data: no replica at least as good as
  another at everything; each leads at its own job; every part and power source gives something and costs
  something; no two parts of a slot and no two springs do the same job; the laser changes nothing aimed.

## Decisions

- **The Cyber Pistol keeps the owner's design.** `docs/DECISIONS.md` has it as "rifle power with pistol handling, the
  tightest spread and almost no kick", so its energy, rate, spread, kick, draw and reload stay; the first table posted
  to the owner (0.70 J, 0.75°) was withdrawn the same hour. Its costs are 30 BB magazines (two seconds of trigger;
  90 a round, the fewest of the automatics) and Moving spread ×2 (running from the hip 1.26° against the AEG's 1.17°
  and the SMG's 0.81°; a walk adds nothing, so walking or standing it is as tight as ever).
- **Pace is a spectrum.** Sniper Rifle 0.95, AEG Rifle 1, pistols 1.04, Compact SMG 1.08. The SMG stays the quickest
  thing to fight with (CS1's identity), over realism: fun beats simulation.
- **The laser is the hip part.** Bots fight from the hip, so a laser helps them most; no kit carries one on a primary.
- **The Vertical Grip steadies the move** (a new column) and not the kick: kick at 0.18° a shot settles at about 0.4°
  on a held trigger, too little for a recoil part to matter.
- **The Long Barrel stays at 10 % energy.** At 15 % the factory dial (0.65) over-lifts the faster BB out of the 15 cm
  band at 25 m, and the best notch (0.60) reaches no further than the standard barrel's 39 m. It loses its tighter
  groups (the Tight-Bore's job) and a third of its handling cost.
- **The springs' own trades (the owner's ask).** Energy was the only thing a spring changed that mattered, so each
  gets its own: the M130 quiet, the M150 loud, slow and kicking (0.6° a shot: through a scope the view jumps and
  hides where the shot went). The steps are uneven on purpose, the last 10 % of energy the dearest in kick and
  noise. The cocking stays 5 % and 10 % slower, as it was: attempt 1 took the M150 to 18 % (a 1.52 s cycle), and the
  critic found the bolt's recording, cut for the M130's 1.25 s and not stretched with the Fire clip
  (`docs/KNOWN_ISSUES.md`), then knocked 0.16 s before the handle was seen home (0.08 s at 10 %). The spring's cost is
  in what the recording and the clip don't have to follow. A test holds that the handle is home after
  `bolt_press_window` opens on every spring.
- **The Low-Cap carries six, not seven.** A seventh magazine box was not tried on the HUD.
- **The Red Dot pays in the draw** (attempt 2, the critic: it was the one part the trade-off test exempted). PP1 made
  it the quick sight (raise ×0.85) because its slight zoom was all it gave, which left it free. An optic's housing is
  weight on the rail, so every optic now slows the draw (a new Optics column: Red Dot and 2x Scope ×1.1, Variable
  Scope ×1.15) and the iron sights are the quickest to hand: 0.45 s against 0.50 s on the AEG Rifle. The card shows the
  draw where an optic changes it. The Sniper Rifle comes with the 2x Scope, so as it comes it now draws in 0.72 s
  (0.65 s bare, the table's figure); its scope also raises quicker than before (0.22 s against 0.24 s).
- **The Sniper Rifle's built-in hip spread is 10** (`sniper.tres` said 6 since PP1; `data/stats.md` has had 10 and
  wins at start, so nothing changes in play).
- **Kick is bolder, not new.** The LiPo's 30 % lifts a held AEG trigger's climb from about 0.38° to 0.55° (29 cm at
  30 m, from 20); Black Gas on the pistol from 0.71° to 0.95° at its slower 6.3 shots a second.

## Bot bench

A scratch bench (the SN3 bench's tally, with a kit table of fourteen kits weighted alike): Normal bots, 6v6
Elimination, seeds 1 to 10 on Depot and Woodland, on `main` (0bde7c2) and on this branch. Hits per hit taken, both maps
together (bot-rounds in brackets):

| Kit | Before | After |
|---|---|---|
| AEG Rifle as it comes | 0.96 (143) | 1.16 (144) |
| AEG, Vertical Grip | 1.35 (101) | 1.29 (104) |
| AEG, Tight-Bore Barrel | 1.22 (142) | 1.13 (149) |
| AEG, Long Barrel | 1.39 (150) | 1.25 (150) |
| AEG, LiPo | 0.91 (74) | 1.41 (75) |
| AEG, Red Laser | 0.98 (117) | 1.17 (108) |
| AEG, Hi-Cap | 1.00 (140) | 1.30 (140) |
| AEG, Low-Cap | 1.01 (191) | 0.98 (201) |
| Cyber Pistol | 0.78 (84) | 0.72 (96) |
| GBB Pistol as the primary | 0.85 (126) | 0.66 (127) |
| GBB Pistol, Black Gas | 0.82 (185) | 0.62 (187) |
| Sniper Rifle | 0.73 (83) | 0.66 (82) |
| Compact SMG | 1.19 (30) | 0.83 (31) |
| Compact SMG, Red Laser, LiPo | 0.97 (138) | 0.97 (134) |

What it shows, and what it can't: no kit runs away and none falls out (0.62 to 1.41 after, 0.73 to 1.39 before), the
barrels stay close to each other, and the Compact SMG still wins on Depot and loses on Woodland (1.17 and 0.80 with the
laser and LiPo, 1.15 and 0.81 before). But about a hundred hits a kit leaves each figure good to about ±0.15: the AEG
as it comes, whose numbers did not change, moved from 0.96 to 1.16. So the bench is a check that nothing broke, not a
measure of a 20 % part; bots also fire from the hip, never draw a sidearm and never aim a scope, so the laser's and
the scopes' new costs and the pistols' draw don't show in it at all. The numbers themselves rest on the reach and
spread measured from the data (What was wrong, Decisions). No number was changed on the bench's word. Reports:
`/mnt/project-files/pipeline/runs/RP1/attempt-1/kit-bench-before.md` and `kit-bench-after.md`.

## Review

- **Critic, attempt 1 (7/8, Retry):** the Red Dot was a straight upgrade, against "parts are trade-offs, never
  straight upgrades". Fixed: the Optics table's Draw column (Decisions). Its other findings, all taken: the M150's
  slower bolt left its recording 0.16 s ahead of the handle (the cocking is back to 5 % and 10 %); `sniper.tres` and
  the table disagreed on the hip spread; the wiki blamed "one hand" for the Cyber Pistol's spread on the run, which
  the GBB Pistol, held the same way, does not have.
- **Critic, attempt 2 (8/8, Accept):** the Sniper Rifle's draw as it comes (with its scope) is noted in `stats.md` and
  the wiki; the Red Dot's cost is real but small (0.05 s), for the owner to judge in play.
- **QA (Pass, both attempts):** no defect found. Two tests added: the Cyber Pistol takes no grip or laser, so its
  spread on the run can't be bought off; the Sniper Rifle with its scope draws slower than without it.
- **Performance (Pass, both attempts):** judged from the diff, nothing runs per frame or per tick. Advisory:
  `pipeline/perf-budget.json` does not exist, so there is no measured baseline.
- The Depot match guards (Elimination at Normal, Attack / Defend) were run on attempt 1's numbers and pass.

## Known issues left

- `docs/KNOWN_ISSUES.md` › Balance: RP1's numbers are from the data and a bot bench, not from play (the owner's
  playtest; the play checks are on the Dev 3 checklist); the Hi-Cap's rattle is still heard only at a walk.
