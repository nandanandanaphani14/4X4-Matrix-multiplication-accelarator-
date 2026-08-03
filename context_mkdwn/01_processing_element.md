# Chunk 01 — Processing Element (`MAC.sv` → `processing_element`)

The only module with arithmetic. 16 instances form the array.

## Registers
`weight_q [7:0]`, `a_q [7:0]`, `valid_q`, `psum_q [31:0]` — all cleared by synchronous `!rst_n`.

## Combinational
```
product_ext = 32'(weight_q * a_in);   // signed × signed, sign-extended
adder_out   = psum_in + product_ext;
```

## Sequential (posedge clk)
```
if (wload) weight_q <= psum_in[7:0];  // capture weight from shared vertical bus
a_q     <= a_in;
valid_q <= valid_in;
psum_q  <= valid_in ? adder_out : psum_in;   // accumulate OR pass-through (bypass)
```

## Outputs
```
a_out     = a_q;
valid_out = valid_q;
psum_out  = wload ? 32'(weight_q) : psum_q;   // COMBINATIONAL mux — load-bearing
```

## Three load-bearing facts
1. **Vertical bus is time-multiplexed** — carries weights during `wload`, partial sums during compute. Only low 8 bits of `psum_in` are captured as a weight.
2. **During `wload`, `psum_out` is combinational off `weight_q`.** This makes each array column a **downward shift register** during weight load: the value fed *first* travels *furthest* (→ bottom row). This is the basis of weight-load rule (see [[02_systolic_array]], [[12_dataflow_and_timing]]).
3. **`valid_in=0` is a bypass, not a stall.** Partial sums march south one row/clock regardless; a bubble produces junk that flushes itself out. No back-pressure anywhere.

## Known-good directed vectors (from prior TB)
- `weight=3, a=5, psum_in=100 → 115`
- `(−4)×7 = −28`
- `(−128)×(−128) = +16384`
- `50 + 127×(−2) = −204`
- during `wload`, weight `−3` appears on `psum_out` as `0xFFFFFFFD`

Related: [[02_systolic_array]], [[12_dataflow_and_timing]], [[test_plan]].
