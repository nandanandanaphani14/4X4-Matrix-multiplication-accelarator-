# Chunk 06 — Memories (`a_mem.sv`, `weight_mem.sv`, `outmem.sv`)

One single-port synchronous RAM primitive at three geometries. Whole body:
```
always_ff @(posedge clk) begin
  if (we) mem[addr] <= wdata;
  rdata <= mem[addr];          // unconditional, registered read
end
```

| Module | File | Depth × Width | ADDR_W | Word contents |
|--------|------|---------------|--------|---------------|
| `a_mem` | `a_mem.sv` | 256 × 32 | 8 | 4× int8, lane *r* = activation for array ROW *r* |
| `weight_mem` | `weight_mem.sv` | 4 × 32 | 2 | 4× int8, lane *c* = weight for array COLUMN *c*; addr *r* = weight row *r* |
| `output_mem` | `outmem.sv` | 256 × 128 | 8 | 4× int32, lane *c* = result of array COLUMN *c* |

## Three load-bearing properties
1. **One address port, shared read/write.** A write cycle is not a read cycle → forces port
   arbitration at L3 ([[11_wrapper_L3_system_top]]).
2. **One clock of read latency** (registered `rdata`) → the reason `accelerator_top` re-times
   `wload`/`valid_in` ([[10_wrapper_L2_accel_top]]).
3. **Read-before-write on address collision** (both non-blocking) → a read colliding with a write to
   the same address returns the **old** contents.

## Why `weight_mem` is 4×32 but `a_mem` is 256×32
The depths differ by 64× because of the **weight-stationary** dataflow, not an arbitrary choice:
- **`weight_mem` holds one whole matrix, once.** The array has `ROWS=4` rows; each 32-bit word packs
  the four int8 weights of one weight row. Four rows ⇒ four words ⇒ `ADDR_W=2`. Weights are loaded
  into the 16 PEs once per job and stay resident — never re-fetched during compute. A 4×4 int8 matrix
  *is* 4×32 bits; a deeper weight memory would be dead silicon.
- **`a_mem` holds a whole stream of activation vectors.** Activations are the data that *moves* — one
  32-bit word per vector, `num_vectors` streamed one per clock. 256 words = up to 256 activation
  vectors multiplied against a **single** weight load without reloading weights. That amortisation
  (pay the weight-load cost once, reuse over many activation rows) is the entire economic point of a
  weight-stationary array.
- Traffic rates: weights = `ROWS×COLS` bytes **per job**; activations = `ROWS` bytes **per vector**.
  `output_mem` mirrors `a_mem`'s depth (256×128) — one result vector per activation vector.

## Word / lane layout (getting a lane wrong transposes a matrix silently)
```
a_mem word     [31:24][23:16][15:8][7:0] = row3 row2 row1 row0
weight_mem[r]  [31:24][23:16][15:8][7:0] = col3 col2 col1 col0   (weights of row r)
output_mem     [127:96][95:64][63:32][31:0] = col3 col2 col1 col0 (int32 results)
```
No reset — reads of unwritten addresses return `X` in simulation.

Related: [[10_wrapper_L2_accel_top]], [[14_coverage_boundaries]].
