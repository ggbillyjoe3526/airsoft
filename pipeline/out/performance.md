Task: none · BP6 part 1 (graphics) · Verdict: Pass
- figure_bench 11 figures, shared machine: animation+skeleton mean 2.46/2.37 ms (main) vs 2.31/2.40 (head);
  set_body one-time 191.7/186.3 vs 277.7(outlier)/201.6 ms, behind the loading screen.
- Delta to 078b11b: no per-frame work or allocation added; 6 merged meshes, 5,796,912 bytes; 1x 2.48 ms, 6x 2.39 ms
  with the eye mid-field.
