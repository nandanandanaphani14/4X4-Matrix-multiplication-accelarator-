# Chunk 02 — Systolic Array (`array.sv` → `systolic_array`)

Pure interconnect — **no arithmetic**. Declares three meshes, instantiates 16 PEs, binds boundaries.

## Meshes (each sized one larger than the grid in its travel direction)
```
a_net    [0:ROWS-1][0:COLS]     // horizontal, west → east
valid_net[0:ROWS-1][0:COLS]     // alongside a_net
psum_net [0:ROWS][0:COLS-1]     // vertical, north → south
```

## Boundaries
- West: `a_net[r][0] = a_in_left[r]`, `valid_net[r][0] = valid_in_left[r]`
- North: `psum_net[0][c] = psum_in_top[c]`
- South out: `psum_out_bottom[c] = psum_net[ROWS][c]`
- PE links: horizontal `a_net[r][c]→[c+1]`, vertical `psum_net[r][c]→[r+1][c]`

Named generate blocks (`row_gen`, `col_gen`) → hierarchical name `u_array.row_gen[r].col_gen[c].pe_inst`.

## Weight-load rule (Rule 1 — silent if wrong)
While `wload=1` the vertical bus is a downward shift register (see [[01_processing_element]]).
To place weight **row r into array row r**, drive `W[ROWS-1]` first and `W[0]` last.
The AGU implements this by counting `w_addr` **down**: 3, 2, 1, 0.
A wrong order still runs, still pulses `done`, still writes plausible numbers — computed against a
vertically flipped W. Only a golden-model check against a **non-symmetric** W catches it.

## Column latency (emergent)
A dense vector consumed at cycle *n* produces column *c*'s result just after cycle
`n + (ROWS-1) + c`. The `+c` is the horizontal-travel **staircase** — column 0 finishes first,
column 3 three cycles later. Removing it is the de-skew buffer's only job ([[05_output_deskew_buffer]]).

Related: [[04_input_skew_buffer]], [[05_output_deskew_buffer]], [[12_dataflow_and_timing]].
