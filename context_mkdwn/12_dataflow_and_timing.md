# Chunk 12 — Dataflow & Timing Derivations

## Notation
- Cycle *n* = the *n*-th posedge. A signal **issued** at *n* is the value just *before* edge *n*
  (the value that edge samples). A signal **observed** at *n* is the value just *after* edge *n*.
- Conflating "issued" vs "observed" caused 2 of 3 historical defects.

## The latency chain (4×4)
| # | Step | Adds | Total |
|---|------|------|-------|
| 1 | Down a PE column (one reg/row) | ROWS-1 = 3 | 3 |
| 2 | East to column *c* | +c | 3+c |
| 3 | De-skew pipe (COLS-1-c) | +(COLS-1-c) | **6**, independent of *c* |
| 4 | `a_mem` read latency | +1 | **7** = RESULT_LATENCY (L2) |
| 5 | Write strobe one cycle after data observable | +1 | **8** = STORE_LATENCY |

## Constant summary
| Constant | Value (4×4) | Formula | Declared in |
|----------|-------------|---------|-------------|
| Array column latency | 3+c | (ROWS-1)+c | array.sv (emergent) |
| De-skew delay | 3−c | COLS-1-c | output_skewbuf.sv |
| L1 result latency | 6 | ROWS+COLS-2 | wrapper_array_buf.sv |
| L2 result latency | 7 | 1+ROWS+COLS-2 | wrapper_mem_arr_buf.sv |
| L2 store latency | 8 | RESULT_LATENCY+1 | wrapper_mem_arr_buf.sv |
| AGU write-pipe depth | 8 | STORE_LATENCY | agu.sv |
| Controller DRAIN | 8 | STORE_LATENCY | controller.sv |
| Total job length | N+19 | ROWS+FLUSH_CYCLES+N+STORE_LATENCY+1 | emergent |

## Three rules
1. **Weight rows load bottom-first** — feed W[ROWS-1] first; AGU counts w_addr down 3,2,1,0.
2. **Control travels with its address** — issue `wload`/`valid_in` in the same cycle as the address;
   `accelerator_top` re-times by one clock. Never pre-delay at the caller.
3. **Fixed latency, no back-pressure** — no ready/valid handshake anywhere; host must respect the numbers.

## FLUSH is belt-and-braces
Strictly not required for correctness (partial sums and weight residue never share a pipeline slot),
but kept so the result bus is visibly quiet before compute — makes the "quiet before compute"
assertions and waveforms meaningful.

Related: [[02_systolic_array]], [[07_controller_fsm]], [[08_agu]], [[13_worked_example]].
