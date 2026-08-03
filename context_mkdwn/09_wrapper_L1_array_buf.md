# Chunk 09 — L1 Wrapper (`wrapper_array_buf.sv` → `array_buf_top`)

**Abstraction level 1 of 3** — the compute fabric only: skew + array + de-skew. No memory, no
sequencing. Caller presents one dense vector/clock and reads `result` a fixed number of clocks later.

## Structure
```
input_skew_buffer  → systolic_array → output_deskew_buffer
```
- `dense_a_in`, `dense_valid_in` (west, un-skewed) → skew buffer → array west edge
- `psum_in_top` (north): weight row during `wload`, zeros during compute
- `result` (south, de-skewed, aligned) + `psum_raw` (south, pre-de-skew, observability only)

## Latency
```
localparam RESULT_LATENCY = ROWS + COLS - 2;   // = 6 for 4×4
```
A dense vector consumed at posedge *n* appears on `result` just after posedge `n + 6`:
`(ROWS-1)` down the column `+ c` east travel `+ (COLS-1-c)` de-skew — the `c` terms cancel.

## Weight loading
While `wload=1` the vertical bus is a downward shift register → drive `W[ROWS-1]` first, `W[0]` last.

Prior TB (`tb_array_buf_top`, 76 checks): algorithmic golden `C = A×W`, whole result aligned on a
single cycle; taps `psum_raw` to confirm the staircase is still there (proving de-skew does the work).

Related: [[02_systolic_array]], [[04_input_skew_buffer]], [[05_output_deskew_buffer]], [[10_wrapper_L2_accel_top]].
