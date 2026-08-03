# Chunk 13 — Worked Example (golden reference for testbenches)

From the architecture doc's cycle-by-cycle animation. Useful as a directed vector.

## Weight matrix W (stationary), row *r* col *c*
```
      c0  c1  c2  c3
 r0 [  2  -1   3   0 ]
 r1 [  1   4  -2   5 ]
 r2 [ -3   2   1   1 ]
 r3 [  0   1   2  -4 ]
```

## Activation vectors A (streamed), A[i][r]
```
      r0  r1  r2  r3
 A0 [  1   2   3   4 ]
 A1 [  5  -1   0   2 ]
 A2 [ -2   3   1   1 ]
```

## Expected result C[i][c] = Σ_r A[i][r] · W[r][c]
```
 C0 = [ -5  17  10  -3 ]
 C1 = [  9  -7  21 -13 ]
 C2 = [ -4  17  -9  12 ]
```

## Phase timeline for a 3-vector job
| Phase | Cycles | What happens |
|-------|--------|--------------|
| WLOAD | 1–4 | `wload=1`; weight rows driven north edge **bottom-first** W[3],W[2],W[1],W[0] |
| FLUSH | 5–10 | `wload=0`, north edge zeros, `valid=0`; push weight residue out the bottom |
| COMPUTE | 11–13 | one dense vector/clock, `valid=1`: A0@11, A1@12, A2@13 |
| DRAIN | 14–21 | last vector still in flight; on L1 fabric C0 aligned after cycle 17 (= 11+ROWS+COLS-2) |

Checkpoints: bottom[0]=−5 after cycle 14 (= 11+(ROWS-1)+0); C0 all four lanes align after cycle 17.

## Full 4×4 × 4×4 matrix multiply (re-verification T5)
Streaming four activation vectors treats A itself as a 4×4 matrix → an ordinary 4×4·4×4 = 4×4
product, one result row per activation row. This is the directed case
`tb_accelerator_system_top` section **T5** checks (hand-verifiable numbers):
```
     A (4×4)              W (4×4)                 C = A × W (4×4)
  [ 1 0 0 0 ]        [  1  2  3  4 ]           [  1  2  3  4 ]   A row0 -> W row0
  [ 0 1 0 0 ]   ×    [  5  6  7  8 ]     =     [  5  6  7  8 ]   A row1 -> W row1
  [ 0 0 1 0 ]        [  9 10 11 12 ]           [  9 10 11 12 ]   A row2 -> W row2
  [ 1 1 1 1 ]        [ 13 14 15 16 ]           [ 28 32 36 40 ]   A row3 = column sums
```
Rows 0–2 reproduce the weight rows; the all-ones activation row 3 yields the column sums
`[28 32 36 40]`. One weight load + four back-to-back compute cycles — the weight-stationary
economics of [[06_memories]]. Confirmed PASS in the recheck (see verification_recheck report).

## Loading convention for a testbench
- `weight_mem[r]` word packs lane *c* = W[r][c] as int8.
- `a_mem[i]` word packs lane *r* = A[i][r] as int8.
- `output_mem` word lane *c* = C[i][c] as int32.

Related: [[12_dataflow_and_timing]], [[test_plan]], [[06_memories]].
