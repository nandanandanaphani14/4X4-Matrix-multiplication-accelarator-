# Chunk 03 — Delay Pipe (`delay_pipe.sv` → `delay_pipe`)

Most-instantiated module (12 copies). `WIDTH`-wide, `DELAY`-deep shift register.

```
generate
  if (DELAY == 0)  assign dout = din;          // a PLAIN WIRE — no register, no reset
  else begin
    logic [WIDTH-1:0] pipe [0:DELAY-1];
    always_ff @(posedge clk)
      if (!rst_n) pipe[*] <= '0;
      else begin pipe[0] <= din; pipe[i] <= pipe[i-1]; end
    assign dout = pipe[DELAY-1];
  end
endgenerate
```

## Governing relation (sampled *just before* the consuming edge)
```
dout(cycle m) == din(cycle m − DELAY)   // holds for every depth, including 0
```

## Why `DELAY=0` must be a wire
Used deliberately by **row 0** of the input skew buffer and **column COLS-1** of the de-skew buffer.
There it must be a genuine wire with no register and no reset. The `gen_no_delay` guard also avoids
declaring a zero-element array (`pipe[0:-1]`), which would fail to elaborate.

## Sampling caveat
Sampled *after* an edge, a combinational wire and a 1-deep register look identical (both show the
pre-edge value). `tb_delay_pipe` samples on the **negative edge**. Two of three historical defects
were violations of this convention.

Directed constants from prior TB: instances with `DELAY` ∈ {0,1,3}; single-pulse walk after reset.

Related: [[04_input_skew_buffer]], [[05_output_deskew_buffer]].
