# context_mkdwn — Master Retrieval Index

Segmented context for the **4×4 weight-stationary systolic-array multiplier**. Each chunk is a small,
self-contained fact set for targeted retrieval. Chunks cross-link with `[[chunk-name]]`.

> Sources: RTL (`SIMPLE_ACCEL_RTL`), architecture doc (`SIMPLE_ACCEL_DOCS/architecture_and_dataflow`),
> prior verification report (`SIMPLE_ACCEL_TB_REPORTS`), and the TB test plan (`SIMPLE_ACCEL_TB`).

## Chunks

| # | File | Retrieve when you need… |
|---|------|--------------------------|
| 00 | [00_system_overview.md](00_system_overview.md) | module inventory, the 3 abstraction levels, what the design does |
| 01 | [01_processing_element.md](01_processing_element.md) | PE/MAC internals, registers, the combinational weight-shift trick |
| 02 | [02_systolic_array.md](02_systolic_array.md) | array interconnect, weight-load rule, column staircase latency |
| 03 | [03_delay_pipe.md](03_delay_pipe.md) | shift-register primitive, DELAY=0 as a wire, sampling caveat |
| 04 | [04_input_skew_buffer.md](04_input_skew_buffer.md) | dense→diagonal, why delay must equal r |
| 05 | [05_output_deskew_buffer.md](05_output_deskew_buffer.md) | de-skew cancellation, single-cycle alignment |
| 06 | [06_memories.md](06_memories.md) | SRAM primitive, word/lane layout, 3 load-bearing properties |
| 07 | [07_controller_fsm.md](07_controller_fsm.md) | phase states/durations, num_vectors=0 guard, handshake |
| 08 | [08_agu.md](08_agu.md) | address counters, write-strobe delay pipe |
| 09 | [09_wrapper_L1_array_buf.md](09_wrapper_L1_array_buf.md) | L1 fabric wrapper, RESULT_LATENCY=6 |
| 10 | [10_wrapper_L2_accel_top.md](10_wrapper_L2_accel_top.md) | L2 + SRAMs, control re-timing, pack/unpack, latency 7/8 |
| 11 | [11_wrapper_L3_system_top.md](11_wrapper_L3_system_top.md) | L3 full system, port arbitration, host protocol |
| 12 | [12_dataflow_and_timing.md](12_dataflow_and_timing.md) | full latency chain, constant table, the 3 rules |
| 13 | [13_worked_example.md](13_worked_example.md) | concrete W/A/C golden vectors + phase timeline |
| 14 | [14_coverage_boundaries.md](14_coverage_boundaries.md) | what is NOT verified, historical defects |
| 15 | [15_test_plan.md](15_test_plan.md) | the TB hierarchy test plan and recheck mapping |

## Topic → chunk quick map
- **Weight-load ordering (bottom-first)** → 01, 02, 08, 12
- **Latency numbers (6 / 7 / 8 / N+19)** → 09, 10, 07, 12
- **Golden model / expected values** → 13, 15
- **Port arbitration / busy** → 06, 11
- **What could silently go wrong** → 02 (load order), 05 (de-skew depth), 06 (lane index)
- **Coverage gaps** → 14

## Cross-folder indexes
Each existing content folder carries its own `index.md` pointing back into these chunks:
`SIMPLE_ACCEL_RTL`, `SIMPLE_ACCEL_TB`, `SIMPLE_ACCEL_DOCS`, `SIMPLE_ACCEL_TB_REPORTS`, and
`verification_recheck`.
