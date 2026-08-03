# FPGA_IMPL — ZedBoard implementation of the 4×4 systolic accelerator

How to run the (unmodified) accelerator on a **Digilent ZedBoard** (Zynq-7000,
`xc7z020clg484-1`) using **only on-board switches, buttons and LEDs** — no external peripheral
connectors — plus richer peripheral-free alternatives.

## Contents
| File | What |
|------|------|
| [ZedBoard_Implementation_Guide.html](ZedBoard_Implementation_Guide.html) | **the main how-to** — plan, I/O scheme, resources, Vivado flow, bring-up test, and a step-by-step walkthrough for all four interface options. Animated. |
| [rtl/fpga_top.sv](rtl/fpga_top.sv) | Option 1 console harness: debouncers + loader FSM + result capture + LED mux around `accelerator_system_top` (elaborates clean) |
| [rtl/accel_axi.sv](rtl/accel_axi.sv) | Option 3/4 AXI4-Lite slave wrapper around `accelerator_system_top`, with sticky-done (elaborates clean) |
| [sw/accel_monitor.c](sw/accel_monitor.c) | Option 3 bare-metal UART monitor (text menu: enter matrices, run, print result) |
| [zedboard_accelerator.xdc](zedboard_accelerator.xdc) | Option 1 pin-constraint template (clk / SW / LED / buttons) — **verify against the Digilent master XDC for your board rev** |

## The idea in one paragraph
A job finishes in ~230 ns at 100 MHz — too fast to watch — and 8 switches / 8 LEDs cannot hold a 4×4
matrix. So `fpga_top.sv` adds a small **console FSM**: enter each int8 byte on the switches, commit
with the center button (pointer auto-advances), press UP to run the job at full speed, and read the
latched 4×4 result one byte at a time (switches select which byte, LEDs show it). The accelerator RTL
is **not modified** — the harness drives its `host_*` ports exactly as the testbench did in simulation.

## Interface options (all peripheral-free) — each has a full step-by-step in the guide §9
1. **Switches + LEDs** — `fpga_top.sv` + XDC. Self-contained board demo.
2. **Vivado VIO + ILA over JTAG** — drive/observe from the PC over the programming cable; the only way
   to watch the pipeline cycle-by-cycle on real hardware.
3. **USB-UART text console** — type matrices / read results in a serial terminal. On the ZedBoard the
   USB-UART is a **PS** resource (UART1, MIO48/49), so this uses a minimal PS + `accel_axi.sv` +
   `accel_monitor.c`.
4. **Full PS/AXI integration** — scale the same base with AXI-DMA, a done-interrupt, or a Linux/UIO driver.

## Build (option 1)
1. Vivado RTL project, part `xc7z020clg484-1`.
2. Add all 13 files from `…SIMPLE_ACCEL_RTL/` **+** `rtl/fpga_top.sv`; set `fpga_top` as top.
3. Add `zedboard_accelerator.xdc` (verify pins).
4. Synthesis → Implementation → Generate Bitstream (PL-only Zynq design).
5. Hardware Manager → Program Device → interact per the guide's §4/§8.

> `fpga_top.sv` elaborates cleanly against the design (checked with QuestaSim `vopt`). It can also be
> simulated by wrapping it in a small testbench that pulses the debounced buttons.

Design reference: [`../context_mkdwn/`](../context_mkdwn/index.md). Functional baseline:
11/11 testbenches, 3 564 checks, 0 mismatches ([`../verification_recheck/`](../verification_recheck/index.md)).
