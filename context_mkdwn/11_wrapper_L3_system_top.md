# Chunk 11 — L3 Wrapper (`wrapper_full_system.sv` → `accelerator_system_top`)

**Abstraction level 3 of 3** — the entire design: L2 + controller + AGU + port arbitration.
Instantiates `accelerator_top` (byte-for-byte the L2-verified datapath).

## Blocks (one instance per architecture box)
- `u_controller` (controller.sv) — phase FSM
- `u_agu` (agu.sv) — addresses + write-strobe pipe
- `u_datapath` (accelerator_top) — memories + fabric + packing

## Port arbitration (single-port SRAMs → one master)
```
busy = 0 : host owns all three ports (preload matrices, read results). output_mem host side read-only.
busy = 1 : AGU owns all three ports; host write strobes forced to 0 (a_we_mux=w_we_mux=0).
```
This masks stray host writes during a live job. `agu_wload`/`agu_valid_in` bypass the mux and feed
`accelerator_top` directly (which re-times them internally).

## Host usage protocol
1. hold `rst_n` low, release.
2. while `!busy`: write activation vectors + weight rows via `host_*` ports.
3. pulse `start` with `num_vectors` / `act_base` / `out_base` valid.
4. wait for the `done` pulse (single cycle; `busy` already low).
5. while `!busy`: read results via `host_o_addr` / `o_rdata`.

Job length = `num_vectors + 19`. `start` ignored while busy. `num_vectors = 0` legal, does not hang.

Prior TB (`tb_accelerator_system_top`, 201 checks): 4 jobs incl. an adversarial run hammering both
write ports with garbage (`0xDEADBEEF`/`0xBAADF00D`) throughout — results bit-identical, proving the
arbitration masks host writes; `act_base`/`out_base` isolation; a 3-vector short run.

Related: [[07_controller_fsm]], [[08_agu]], [[10_wrapper_L2_accel_top]], [[12_dataflow_and_timing]].
