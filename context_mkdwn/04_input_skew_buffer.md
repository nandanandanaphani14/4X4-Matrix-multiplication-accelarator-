# Chunk 04 — Input Skew Buffer (`input_buf.sv` → `input_skew_buffer`)

Converts a **dense** activation column into a **diagonal wavefront**. Four pairs of `delay_pipe`,
row *r* with `DELAY = r`; the valid bit gets its own matching pipe so data and valid never separate.

```
for (r = 0; r < ROWS; r++) begin
  delay_pipe #(.WIDTH(WIDTH), .DELAY(r)) u_a_delay ( dense_a_in[r]     -> skew_a_out[r] );
  delay_pipe #(.WIDTH(1),     .DELAY(r)) u_v_delay ( dense_valid_in[r] -> skew_valid_out[r] );
end
```

## Why the delay must be exactly *r*
Activations travel east one column/cycle, so the activation reaching PE[r][c] at cycle *t* entered
row *r* at *t − c*. For the column sum to be a genuine dot product, every row must contribute an
element of the **same** activation vector ⇒ row *r* must be delayed by *r* relative to row 0.
The skew delay is not a convenience; it is what makes the array compute the right thing at all.

Row 0 uses `DELAY=0` (a wire — see [[03_delay_pipe]]). Verified points from prior TB: row *r* delayed
by exactly *r* clocks; valid travels with data; diagonal wavefront; reset flushing.

Related: [[02_systolic_array]], [[05_output_deskew_buffer]].
