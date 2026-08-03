# Chunk 10 — L2 Wrapper (`wrapper_mem_arr_buf.sv` → `accelerator_top`)

**Abstraction level 2 of 3** — L1 + the three SRAMs, host-sequenced. Instantiates `array_buf_top`
(never re-wires it).

## What it adds
- `a_mem`, `weight_mem`, `output_mem` instances.
- **Control re-timing**: `wload_q <= wload; valid_q <= valid_in;` — one clock, to cover SRAM read
  latency (Rule 2). Addresses are *not* re-timed; control is.
- **Unpack**: `a_rdata` → four signed int8 `dense_a[r]`; `dense_v[r] = valid_q`.
- **North drive**: `psum_top[c] = wload_q ? sign_ext(w_rdata[c*8+:8]) : 0`.
- **Pack**: `o_wdata[c*32+:32] = result[c]` → one 128-bit output word.

## Latency
```
RESULT_LATENCY = 1 + ROWS + COLS - 2 = 7   // a_addr issued at n → result just after n+7
STORE_LATENCY  = RESULT_LATENCY + 1  = 8   // o_we must be high at n+8 to capture
```
The extra `+1` over L1 is the `a_mem` read latency.

## Ports
Shared read/write address per SRAM (`a_*`, `w_*`, `o_*`); host side of `output_mem` is read-only.
Live `result[0:COLS-1]` bus exposed ahead of the output SRAM.

Prior TB (`tb_accelerator_top`, 76 checks): host preloads `a_mem`/`weight_mem`, shifts weights,
flushes, streams vectors (burst+gap+burst), stores, reads `output_mem` back, compares `C=A×W` lane by
lane; checks quiet-after-flush and preload-still-intact.

Related: [[06_memories]], [[09_wrapper_L1_array_buf]], [[11_wrapper_L3_system_top]], [[12_dataflow_and_timing]].
