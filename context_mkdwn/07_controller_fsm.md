# Chunk 07 — Controller FSM (`controller.sv` → `controller`)

Owns **phase durations only** — produces no addresses. Emits four phase enables + status.

## States & durations
| State | Enc | Length | Note |
|-------|-----|--------|------|
| `PH_IDLE` | 0 | — | wait `start`; latch `num_vectors` into `vec_n` |
| `PH_WLOAD` | 1 | `ROWS` = 4 | shift weight matrix in |
| `PH_FLUSH` | 2 | `FLUSH_CYCLES` = `ROWS+2` = 6 | drain weight residue |
| `PH_COMPUTE` | 3 | `num_vectors` | one activation vector/clock |
| `PH_DRAIN` | 4 | `STORE_LATENCY` = 8 | last result still in flight |
| `PH_DONE` | 5 | 1 | `done` pulses, `busy` already low |

`STORE_LATENCY = 1 + ROWS + COLS - 2 + 1 = 8`. **Total job = num_vectors + 19** (`4+6+N+8+1`).

## Outputs
`busy = (state != IDLE) && (state != DONE)`; `done = (state == DONE)`; phase enables are one-hot on state.

## Load-bearing behaviours
- **`num_vectors = 0` must not hang.** FLUSH exits to `(vec_n==0) ? PH_DRAIN : PH_COMPUTE`. Without
  the guard, COMPUTE would compare `cnt == 8'hFF` and sit 256 cycles issuing garbage writes.
- **`start` sampled only in IDLE**, ignored while busy — a stray mid-job pulse changes nothing.
- **`done` is a single-cycle pulse**; `busy` is already low when it fires.
- Reset mid-job → IDLE; FSM still accepts a fresh job afterward.

Prior TB: 85 checks; phase lengths measured by counting enable-high clocks for
`num_vectors ∈ {0,1,3,4,6,8,16}`; total job length measured independently. Defect #3 was a TB
counter-clear-timing bug (measured WLOAD as 3), RTL was correct.

Related: [[08_agu]], [[11_wrapper_L3_system_top]], [[12_dataflow_and_timing]].
