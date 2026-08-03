# Verification Re-check Report — 4×4 Weight-Stationary Systolic Accelerator

**Date:** 2026-08-03
**Simulator:** QuestaSim 2021.1 (`C:\questasim64_2021.1\win64\vsim.exe`)
**Scope:** an **independent** functional re-verification of every RTL module in the
`SIMPLE_ACCEL_RTL` branch, driven by a freshly-written testbench suite that follows the test plan in
`SIMPLE_ACCEL_TB/README.md`. The original RTL was **not modified**.

> This report and all its artifacts live in the created `verification_recheck/` folder. The original
> report and transcripts in `SIMPLE_ACCEL_TB_REPORTS/` are left untouched as the historical baseline.

---

## 1. Headline result

| | |
|---|---|
| Testbenches run | **11 / 11 passed** |
| Individual checks executed | **3 564** |
| Mismatches | **0** |
| Compile errors | 0 |
| RTL defects found | **0** (design re-confirmed correct) |
| Testbench defects found & fixed | 1 (see §5) |

Machine-readable roll-up: [`logs/regression_summary.txt`](logs/regression_summary.txt).
One full transcript per testbench: [`logs/`](logs/). Reproduce with:

```powershell
.\testbenches\run_all_testbenches.ps1
```

The script compiles the unmodified RTL + the testbenches, runs each in batch, tees a transcript per
testbench, and exits non-zero if any fails (CI-usable).

---

## 2. Results table

| # | Testbench | DUT | Level | Checks | Result |
|---|-----------|-----|-------|--------|--------|
| 1 | `tb_delay_pipe` | `delay_pipe` | leaf | 125 | PASS |
| 2 | `tb_processing_element` | `processing_element` (MAC.sv) | leaf | 1 546 | PASS |
| 3 | `tb_memories` | `a_mem` / `weight_mem` / `output_mem` | leaf | 88 | PASS |
| 4 | `tb_input_skew_buffer` | `input_skew_buffer` (input_buf.sv) | leaf | 957 | PASS |
| 5 | `tb_output_deskew_buffer` | `output_deskew_buffer` (output_skewbuf.sv) | leaf | 482 | PASS |
| 6 | `tb_systolic_array` | `systolic_array` (array.sv) | fabric | 28 | PASS |
| 7 | `tb_array_buf_top` | `array_buf_top` | **wrapper L1** | 54 | PASS |
| 8 | `tb_controller` | `controller` | control | 44 | PASS |
| 9 | `tb_agu` | `agu` | control | 34 | PASS |
| 10 | `tb_accelerator_top` | `accelerator_top` | **wrapper L2** | 73 | PASS |
| 11 | `tb_accelerator_system_top` | `accelerator_system_top` | **wrapper L3** | 133 | PASS |
| | | | **TOTAL** | **3 564** | **11/11** |

Check counts are not a quality metric on their own — a random memory sweep racks up checks cheaply,
while each of `tb_systolic_array`'s comparisons is a full 32-bit dot product against an independently
computed golden value. §4 says what each testbench proves.

---

## 3. Verification strategy

Followed the hierarchy in the TB branch's test plan (leaf → fabric → L1 → L2 → L3) and the principles
recorded in the original report:

- **Algorithmic golden model.** From `tb_systolic_array` upward the expected value is `C = A × W`
  computed by a plain nested loop in the testbench — nothing about the expected *value* is derived
  from the RTL.
- **Random, non-symmetric weight matrices.** Any permutation of the weight rows (e.g. a top-first
  load) would fail, so the bottom-first load rule is genuinely exercised, not assumed.
- **Explicit sampling convention per testbench.** Convention A (registered outputs: drive after a
  posedge, consume at the next, then sample) vs Convention B (delay lines / address buses: sample
  before the consuming edge). Each testbench header states which it uses.
- **Negative checks.** A result must *not* appear a cycle early; the datapath must be quiet before
  compute; a short run must not touch neighbouring output words; adversarial host writes must not
  perturb a running job.
- **Rich, reviewable transcripts.** Each log carries a banner, a test plan, decoded stimulus, a
  per-transaction trace with expected values alongside, a per-section tally, and a `TOTALS` /
  `RESULT` footer — matching the format of the original transcripts.

The three abstraction levels are each closed by their own wrapper testbench, and level 3 instantiates
level 2 which instantiates level 1, so the datapath cannot drift between levels.

---

## 4. What each testbench proves

- **`tb_delay_pipe`** — three instances (`DELAY` 0/1/3). `DELAY=0` is a true wire (tracks `din` in the
  same cycle, ignores reset); `DELAY>0` obeys `dout(m)=din(m−DELAY)`; synchronous reset flushes the
  pipe; a single pulse walks the pipe stage by stage.
- **`tb_processing_element`** — directed hand-computed constants (`100+3·5=115`, `(−128)²=16384`,
  `50+127·(−2)=−204`, weight `−3` → `0xFFFFFFFD` on `psum_out` during `wload`, `valid=0` bypass) plus
  a 500-cycle random stream checked every cycle against a cycle-accurate reference model, plus reset.
- **`tb_memories`** — 1-cycle registered read latency, `we=0` hold, **read-before-write** on an
  address collision, `weight_mem` 2-bit **address wrap**, and per-lane word integrity (incl. extreme
  signed 32-bit values) matching the packing conventions.
- **`tb_input_skew_buffer`** — row *r* delayed by exactly *r*; the valid bit travels with its data; a
  single dense vector emerges as a clean diagonal wavefront.
- **`tb_output_deskew_buffer`** — column *c* delayed by `COLS-1-c`; a staircase in → all columns
  aligned on **one** cycle out; empty on every cycle before that; extreme signed values bit-exact.
- **`tb_systolic_array`** — random non-symmetric 4×4 weights loaded bottom-first, several vectors
  streamed with manual skew, every column's dot product compared to `C=A×W`; array drains to 0 after
  the last valid input.
- **`tb_array_buf_top` (L1)** — same golden model with skew/de-skew inside the DUT, so the whole
  result vector appears aligned on one cycle at `ROWS+COLS-2 = 6`; the pre-de-skew bus `psum_raw` is
  tapped to confirm the staircase is real; result bus quiet before the first result.
- **`tb_controller`** — phase lengths measured by counting enable-high clocks (`WLOAD=4`, `FLUSH=6`,
  `COMPUTE=nv`, `DRAIN=8`, `DONE=1`) and total job length `nv+19` for `nv ∈ {0,1,3,4,6,8,16}`; phase
  enables mutually exclusive; `start` ignored while busy (hammered mid-job); `done` a single-cycle
  pulse with `busy` already low; reset mid-job → IDLE then a fresh job still works; **`nv=0` does not
  hang**.
- **`tb_agu`** — weight address counts **down** `ROWS-1…0` and re-arms while idle; activation address
  counts **up** from `act_base`; a write-strobe scoreboard confirms exactly one `out_we` per compute
  cycle, `STORE_LATENCY` cycles later, at address `out_base+i` — flagging extra/missing/misaddressed
  strobes.
- **`tb_accelerator_top` (L2)** — host preloads the SRAMs, shifts weights, flushes, streams, drives
  `o_we` at `STORE_LATENCY`, reads `output_mem` back and compares `C=A×W` lane by lane; live result
  bus checked at `addr + RESULT_LATENCY`; output block re-read unchanged.
- **`tb_accelerator_system_top` (L3)** — the testbench acts only as the host (start / wait done /
  read). Five sections:
  1. clean job, golden read-back;
  2. **adversarial** — hammer both host write ports with `0xDEADBEEF`/`0xBAADF00D` throughout a live
     job → results bit-identical (0 mismatches) and the earlier output block untouched (`out_base`
     isolation);
  3. `act_base` selects a second activation block;
  4. short 3-vector job — exactly three words written, the neighbour word untouched before/after;
  5. **directed 4×4 × 4×4 = 4×4 matrix multiply** (identity-style A) with hand-verifiable numbers
     (result `[[1,2,3,4],[5,6,7,8],[9,10,11,12],[28,32,36,40]]`);
  6. **a second, fully general 4×4 × 4×4 multiply** of two arbitrary integer matrices (result
     `[[17,9,0,−4],[−14,7,11,23],[1,−6,13,−8],[14,−12,8,−13]]`).

---

## 5. Defects found

**No RTL defect was found.** Every module behaved exactly as the architecture document specifies.

One **testbench** defect was found and fixed during bring-up, recorded here for the same reason the
original report recorded its testbench bugs:

| # | Where | Symptom | Cause | Fix |
|---|-------|---------|-------|-----|
| 1 | `tb_agu` (T1) | 4 spurious mismatches on the weight address (`w_addr` = 3 and 2 reported wrong) | Expected value written as `W_ADDR_W'(ROWS-1)` — a **signed** 2-bit cast, so `3`→`2'sb11`→sign-extended to `-1` in the 128-bit compare, while the real unsigned `w_addr` zero-extends to `3` | Pass the plain positive `int` (`ROWS-1`) as the expected value, avoiding the signed narrow cast |

The RTL address bus was correct throughout (`w_addr` = 3, 2, 1, 0 as observed in the transcript); only
the testbench's expected value was mis-typed. This is the same class of bug — a testbench artifact,
not a design fault — that the original regression documented, and it is exactly why golden values are
kept as plain arithmetic.

---

## 6. Coverage boundaries — unchanged from the baseline

This re-check exercises the same functional surface as the original and inherits the same boundaries.
Not covered: arithmetic overflow (unreachable at 4×4 int8 but unguarded), uninitialised-memory reads,
parameter sweeps (verified only at `ROWS=COLS=4`), per-row `valid`, CDC/reset-domain issues, and
back-pressure (none exists). Out of scope of simulation entirely: synthesis, timing closure,
gate-level/post-layout sim, formal verification, functional-coverage closure, power/area. See
[`../context_mkdwn/14_coverage_boundaries.md`](../context_mkdwn/14_coverage_boundaries.md).

"11/11 passing, 3 564 checks" is a pass rate, not a coverage number.

---

## 7. Files

```
verification_recheck/
├── verification_recheck_report.md      this file
├── index.md                            folder index -> context chunks
├── testbenches/
│   ├── tb_common.svh                   shared reporting harness
│   ├── tb_*.sv                          11 testbenches
│   └── run_all_testbenches.ps1         regression driver (CI-usable)
├── logs/
│   ├── compile.log
│   ├── regression_summary.txt
│   └── tb_*.log                        one full transcript per testbench
├── sim/                                QuestaSim work library (generated)
└── doc_backup_original/                pre-edit copies of the DOCS html/pdf
```
