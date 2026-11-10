# QA report SL3
Verdict: Pass (one doc bug to fix, no code bugs).
- glbs (roof_truss, hall_wall, hall_shutter, hall_exit): nodes, scenes, mesh/primitive names, accessor counts and POSITION min/max identical to origin/main; materials identical (one "Prop"); only vertex colours differ. Lamp Lens is in roof_lamp.glb, untouched.
- Targeted tests (test_look, test_props, test_dh1_hall_shell, test_lamp_lights_qa): 56/56 pass. New test fails against the old roof_truss.glb (checked), passes on the new one.
- Palette: 0x8c8a96 = grey, 0xd2cec8 = concrete, both palette entries; neither is a team hue. test_look's _in_palette passes.
- Card pictures: 1920x1080 and 480x270 as before, .import files unchanged.
- Bug 1: docs/wiki/Maps.md:26 still says "crimson steel columns" for the hall; SL3 repainted the frames grey. Fix: "galvanised steel columns".
- Note: docs/ASSETS.md has an uncommitted edit ("about 1 MB the four, SL3"); commit it or drop it. pipeline/out/performance.md is also modified (not mine).
