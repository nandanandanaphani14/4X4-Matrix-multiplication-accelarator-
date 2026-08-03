# Chunk 14 — Coverage Boundaries (what is NOT verified)

Stated plainly so a green regression is not read as stronger than it is.

## Not exercised by any test
- **Arithmetic overflow.** `psum` is 32-bit, no saturation. Worst case at 4×4 int8 is
  `4×128×128 = 65 536` → unreachable here, but nothing guards a larger ROWS / wider inputs.
- **Uninitialised memory reads.** All three SRAMs power up `X`; tests only read written addresses.
- **Parameter sweeps.** Everything at `ROWS=COLS=4`. `systolic_array` ports are hard-coded
  `[7:0]`/`[31:0]`, so `DATA_W`/`PSUM_W` are effectively fixed at 8/32.
- **Per-row valid.** `valid_in` is one bit broadcast to all rows; independent per-row valid is
  structurally supported but never driven.
- **CDC / reset-domain.** Single clock, synchronous reset, no CDC.
- **Back-pressure.** None in the architecture; host must respect latency numbers.
- **No load engine** (`agu_load.sv` was anticipated but not built) — host preloads memories directly.

## Out of scope of simulation entirely
- No synthesis, timing closure, gate-level / post-layout sim. `vlog` passing ≠ design builds
  (port-connection type checks happen at elaboration/`vopt`, not compile).
- No formal property verification.
- No functional-coverage collection. "N/N passed" is a pass rate, not a coverage number.
- No power/area analysis.

## Historical defects (all in TB code, none in RTL)
1. `tb_output_mem`: `128'(-32'sd1)` sign-extends but part-select `rd[32+:32]` is unsigned (zero-extends).
2. `tb_agu`: sampled the address bus after the consuming edge (off by one).
3. `tb_controller`: cleared phase counters after the start pulse (measured WLOAD as 3 not 4).

Related: [[00_system_overview]], [[13_worked_example]].
