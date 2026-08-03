# Chunk 00 — System Overview

**Design:** 4×4 weight-stationary systolic-array integer matrix multiplier with an
on-chip address generator and control FSM. Computes `C = A × W` where `A` is a stream
of activation vectors and `W` is a stationary 4×4 int8 weight matrix.

**No external AXI interface** — matrix data is supplied by a host/testbench through the
memory write ports (see RTL README).

## Module inventory (RTL branch `SIMPLE_ACCEL_RTL`)

| File | Module | Role |
|------|--------|------|
| `MAC.sv` | `processing_element` | int8×int8 MAC, weight-stationary PE |
| `array.sv` | `systolic_array` | 4×4 grid of PEs |
| `delay_pipe.sv` | `delay_pipe` | parameterised N-deep shift register (DELAY=0 ⇒ wire) |
| `input_buf.sv` | `input_skew_buffer` | row *r* delayed by *r* — dense→diagonal |
| `output_skewbuf.sv` | `output_deskew_buffer` | column *c* delayed by `COLS-1-c` — realign |
| `a_mem.sv` | `a_mem` | activation SRAM (1-cycle read) |
| `weight_mem.sv` | `weight_mem` | weight SRAM (1-cycle read) |
| `outmem.sv` | `output_mem` | result SRAM, 128-bit word |
| `controller.sv` | `controller` | phase FSM (IDLE→WLOAD→FLUSH→COMPUTE→DRAIN→DONE) |
| `agu.sv` | `agu` | address generator + write-strobe pipeline |
| `wrapper_array_buf.sv` | `array_buf_top` | **L1**: skew + array + de-skew |
| `wrapper_mem_arr_buf.sv` | `accelerator_top` | **L2**: L1 + three SRAMs |
| `wrapper_full_system.sv` | `accelerator_system_top` | **L3**: L2 + controller + AGU |

## Three abstraction levels
- **L1 `array_buf_top`** — pure datapath, host presents one dense vector/clock.
- **L2 `accelerator_top`** — adds the three SRAMs, host-sequenced.
- **L3 `accelerator_system_top`** — adds FSM + AGU; host only pulses `start` / waits `done`.

Each wrapper *instantiates* the level below (never re-wires it), so the levels cannot drift.

Related: [[01_processing_element]], [[02_systolic_array]], [[12_dataflow_and_timing]].
