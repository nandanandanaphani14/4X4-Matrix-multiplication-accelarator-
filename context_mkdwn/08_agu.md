# Chunk 08 — Address Generator (`agu.sv` → `agu`)

Owns **addresses only** — holds no policy, just counts while a phase enable is high. Knows nothing
about SRAM latency.

## Weight address — counts DOWN
```
if (!wload_phase) w_cnt <= ROWS-1;   // re-armed while idle
else              w_cnt <= w_cnt - 1;  // 3, 2, 1, 0
w_addr = w_cnt;  w_rd_en = wload_phase;  wload = wload_phase;
```
Re-arming while idle means the first WLOAD cycle already presents `ROWS-1`, and a second job restarts
from `ROWS-1`. Counting down places weight row *r* into array row *r* (see [[02_systolic_array]]).

## Activation address — counts UP
```
if (!compute_phase) act_cnt <= 0;
else                act_cnt <= act_cnt + 1;
act_addr = act_base + act_cnt;  act_rd_en = compute_phase;  valid_in = compute_phase;
```

## Output write strobe/address — a delay line, not an equation
```
out_we_pipe[0]   <= compute_phase;
out_addr_pipe[0] <= out_base + act_cnt;
out_*_pipe[i]    <= out_*_pipe[i-1];        // STORE_LATENCY (=8) deep
out_we   = out_we_pipe[STORE_LATENCY-1];
out_addr = out_addr_pipe[STORE_LATENCY-1];
```
The strobe **structurally cannot** drift from the data it belongs to; changing datapath depth means
changing one parameter (`STORE_LATENCY`).

`wload`/`valid_in` are issued in the SAME cycle as their address; `accelerator_top` re-times them by
one clock (Rule 2 — control travels with its address).

Prior TB: 62 checks driven by TB-generated phase enables (so a controller bug can't mask an AGU bug);
write-strobe scoreboard counts extra/missing/misaddressed strobes separately.

Related: [[07_controller_fsm]], [[10_wrapper_L2_accel_top]], [[12_dataflow_and_timing]].
