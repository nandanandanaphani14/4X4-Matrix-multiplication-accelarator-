# Chunk 15 — Test Plan (from `SIMPLE_ACCEL_TB/README.md`)

The TB branch README states the strategy: **test individual elements, then test the system at
increasing abstraction levels** following the module hierarchy.

## Hierarchy (bottom-up)
```
PROCESSING ELEMENT
   ↓
4×4 GRID OF PE
   ↓
MEMORIES
   ↓
DELAY PIPE, INPUT DELAY BUFFER, OUTPUT DESKEW BUFFER
   ↓
ADDRESS GENERATOR UNIT
   ↓
CONTROL UNIT
```

## Recheck mapping (this re-verification — see verification_recheck/)
| Level | DUT | Testbench (recheck) |
|-------|-----|---------------------|
| leaf | `processing_element` | `tb_processing_element` |
| leaf | `delay_pipe` | `tb_delay_pipe` |
| leaf | `a_mem`/`weight_mem`/`output_mem` | `tb_memories` |
| leaf | `input_skew_buffer` | `tb_input_skew_buffer` |
| leaf | `output_deskew_buffer` | `tb_output_deskew_buffer` |
| fabric | `systolic_array` | `tb_systolic_array` |
| L1 | `array_buf_top` | `tb_array_buf_top` |
| control | `controller` | `tb_controller` |
| control | `agu` | `tb_agu` |
| L2 | `accelerator_top` | `tb_accelerator_top` |
| L3 | `accelerator_system_top` | `tb_accelerator_system_top` |

## Verification principles (carried over)
- **Algorithmic golden model** `C = A×W` from `tb_systolic_array` up — expected values owe nothing to RTL.
- **Non-symmetric random W** so any weight-row permutation fails (catches the silent load-order bug).
- **Negative checks** — result must not appear a cycle early; datapath quiet before compute; short
  runs must not touch neighbouring output words.
- **Explicit sampling convention** stated per testbench (registered outputs vs delay-line/address bus).

Related: [[00_system_overview]], [[13_worked_example]], [[14_coverage_boundaries]].
