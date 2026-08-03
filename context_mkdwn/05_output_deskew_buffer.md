# Chunk 05 — Output De-skew Buffer (`output_skewbuf.sv` → `output_deskew_buffer`)

Undoes the `+c` column staircase from [[02_systolic_array]]. Column *c* delayed by `COLS-1-c`.

```
for (c = 0; c < COLS; c++)
  delay_pipe #(.WIDTH(WIDTH), .DELAY(COLS-1-c)) ( psum_in[c] -> aligned_out[c] );
```

## The cancellation
```
column c result appears at   n + (ROWS-1) + c
de-skew delay adds           + (COLS-1-c)
                             ─────────────────
aligned at                   n + ROWS + COLS − 2   ← independent of c
```
Column 0 finishes first → delayed most (`COLS-1=3`). Column `COLS-1` finishes last → plain wire
(`DELAY=0`, ignores reset). Because the aligned time is independent of *c*, all four lanes emerge on
the **same cycle**, so `accelerator_top` can concatenate them into one 128-bit word.

Any other de-skew depth would silently pack four results from four *different* vectors into one word.

Prior TB: 188 checks incl. staircase-in / single-cycle-out alignment and empty-until-last-column.

Related: [[02_systolic_array]], [[09_wrapper_L1_array_buf]], [[12_dataflow_and_timing]].
