# game/play/figures

The rigged figures (step 23, `/mnt/project-files/plan/step23-figures.md`): `human.glb` and `robot.glb` from
`assets/models/characters/` drawn for the other players. Presentation only: the figures read the state and never
write it (docs/ARCHITECTURE.md › Contracts 1). Since FI7 every bot is drawn as one on every preset, with no switch
(DECISIONS BD1); the capsules are gone. PlaySession loads the models as it builds the views, behind the loading
screen. Tuning: `FigureConfig` (`game/config/figure_config.gd`, on PlayTuning).

| File | What |
|---|---|
| `figure_models.gd` | `FigureModels`: each kind loaded once a session (scene, sidecar, clips looped as the sidecar says, the fire clips' additive copies, the grip places turned from Blender's axes, the rifle's place on the back and its fit to the pack, the pistol's holster); the team-painted materials and the shadow twins' meshes, made once and shared. A kind it can't read warns and draws no body; `materials` lists every one the kinds wear, for ShaderPrewarm |
| `figure_sidecar.gd` | `FigureSidecar`: a sidecar json, typed (clips, parts, `replicaOnGrip`, `magazineInHand`); the matrices as the file gives them, in Blender's axes |
| `figure_body.gd` | `FigureBody`: one character's figure: one head by id, a level of detail by distance (visibility ranges on the Mesh detail's lines), one shadow twin, the Team* paint, bones by name, the fade through `transparency`; its legs' AnimationTree (the kind's graph, advanced by hand in `animate`) and its FigureBend |
| `figure_pose.gd` | `FigurePose`: a character between two ticks as the legs' targets (the step in the figure's frame, crouch, backwards, jump, vault, the hit call, the walk-off, the lean) and the upper body's (pitch, hold, holster, a switch, what is in the hand, on the back, in the holster or hanging, a reload's share from reload_left), eased at the browser's settle times; pure, one per figure, no allocation |
| `figure_graph.gd` | `FigureGraph`: the figure's graph, one a kind (gait BlendSpace2D, crouch BlendSpace1D, Blend2 layers, TimeSeeks), the stepping clips stretched to one walk cycle with their forward swing at the hit legs'; over the legs a filtered Blend2 for the upper body (aim by pitch, hold, holster, the Reload OneShot over a TimeSeek seeked to the reload's share, Switch OneShot; each branch that can sit weightless behind a Transition gate, its stand-in `gate_clip`) and the trigger press as an additive OneShot; the parameter paths |
| `figure_bend.gd` | `FigureBend`: a SkeletonModifier3D after the tree: the crouched head kept under 1.15 m, the upper chain leaned about the hip pivot, and flinched about it (FI5), then pitched about the spine by what the aim clips leave of the pitch (FI3), the head bowed onto a rifle's stock (TP2, as the hit volume's), then FigureReady: the fist onto the grip (TP3), the rifle's butt into the shoulder (TP2) and the high ready at a wall (FB5) |
| `figure_ready.gd` | `FigureReady`: the hands moved by two-bone IK, each arm reaching its hand's new place: the right fist (both, on a pistol) along the replica onto its grip (TP3, `FigureConfig.grip_fit`); a rifle's butt into the shoulder pocket, turned with the chest (TP2); the high ready at a wall (FB5): the replica turned muzzle up about the grip, canted and drawn in to the chest; FigureView's ray sets how far (`FigurePose.raise`) |
| `figure_flinch.gd` | `FigureFlinch`: the hit flinch (FI5): the upper body's tilt the way the BB flew, in over flinch_rise and eased back over flinch_time, a second hit starting from the tilt drawn; pure, one per figure, no allocation |
| `figure_hands.gd` | `FigureHands`: the figure's replicas (FigureView's figure versions) placed each time the skeleton is posed: in the hand on Grip_R by the sidecar's replicaOnGrip, out of the hand the first rifle resting on the pack (on Chest) and the first pistol in the belt holster (Hips, a tenth of Thigh_R), hanging from the hand calling the hit; in a reload a copy of the replica's figure magazine (or its magazine part's) on Hand_L by the sidecar's magazineInHand (the old one, then the new), the old one thrown at its release, the well's own hidden while it is empty |
| `thrown_magazines.gd` | `ThrownMagazines`: the thrown magazines (FI4), a fixed pool of `thrown_max` copies built once a session, each taking the thrower's magazine mesh and paint: each falls under gravity, comes to rest on its side at the thrower's feet and goes after its lifetime; `thrown_max` out at most, the oldest first; cleared at ROUND_START |
| `figure_mix.gd` | `FigureMix`: who is a robot: half of each team, from the match seed on a stream of its own; only while Settings › Dev › Robots is on (`DevSettings.robots`, the Easter egg, RB1); otherwise everyone is human |

Tests: `tests/unit/test_figure_models.gd`, `test_figure_body.gd`, `test_figure_mix.gd`, `test_figure_view.gd`,
`test_figure_pose.gd`, `test_figure_animator.gd`, `test_figure_flinch.gd`, `test_figure_legs_qa.gd`, `test_figure_hands.gd`,
`test_figure_hands_qa.gd`, `test_figure_flinch_qa.gd`, `test_thrown_magazines.gd`, `test_figure_raise.gd` (FB5),
`test_figure_copies.gd` (the replicas' figure copies and their parts, TP1); the hit area against the drawn figure
`test_figure_hit_area.gd` (`tests/support/hit_area_probe.gd`, FI7). The bench: `tools/figure_bench.gd` (11 figures on
Depot for 30 s; dev only).
