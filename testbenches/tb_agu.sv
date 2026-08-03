`timescale 1ns/1ps
//=====================================================================
// tb_agu  --  DUT: agu (agu.sv)
//
// Driven by TESTBENCH-generated phase enables (not the real FSM), so a
// controller bug cannot mask an AGU bug.  Convention B for address buses
// (sample before the consuming edge).
//
// Checks: weight address counts DOWN ROWS-1..0 and re-arms while idle;
// activation address counts UP from act_base; and a write-strobe
// scoreboard verifies each compute cycle produces exactly one out_we,
// STORE_LATENCY cycles later, at address out_base+i -- flagging extra,
// missing and misaddressed strobes.
//=====================================================================
module tb_agu;
  localparam int ROWS=4, COLS=4, A_ADDR_W=8, W_ADDR_W=2, O_ADDR_W=8;
  localparam int SL = 1+ROWS+COLS-2+1;   // STORE_LATENCY = 8
  logic clk=0, rst_n, wload_phase, compute_phase;
  logic [A_ADDR_W-1:0] act_base;
  logic [O_ADDR_W-1:0] out_base;
  logic [W_ADDR_W-1:0] w_addr; logic w_rd_en, wload;
  logic [A_ADDR_W-1:0] act_addr; logic act_rd_en, valid_in;
  logic [O_ADDR_W-1:0] out_addr; logic out_we;
  always #5 clk = ~clk;

  agu #(.ROWS(ROWS), .COLS(COLS), .A_ADDR_W(A_ADDR_W), .W_ADDR_W(W_ADDR_W),
        .O_ADDR_W(O_ADDR_W), .STORE_LATENCY(SL)) dut (
    .clk(clk), .rst_n(rst_n), .wload_phase(wload_phase), .compute_phase(compute_phase),
    .act_base(act_base), .out_base(out_base),
    .w_addr(w_addr), .w_rd_en(w_rd_en), .wload(wload),
    .act_addr(act_addr), .act_rd_en(act_rd_en), .valid_in(valid_in),
    .out_addr(out_addr), .out_we(out_we));

  `include "tb_common.svh"

  localparam int NV = 5;
  localparam int ABASE = 8'h10, OBASE = 8'h40;

  // scoreboard of observed write strobes
  int obs_cnt = 0;
  int obs_g   [0:63];
  int obs_addr[0:63];
  int gcyc;

  initial begin
    TB = "tb_agu";
    $display("=====================================================================");
    $display(" %s  --  DUT: agu (agu.sv)   STORE_LATENCY=%0d", TB, SL);
    $display("=====================================================================");
    $display(" Convention B (address buses sampled before the consuming edge)");
    $display("");
    $display(" TEST PLAN");
    $display("   T1  weight address counts down ROWS-1..0, re-arms while idle");
    $display("   T2  activation address counts up from act_base");
    $display("   T3  write-strobe scoreboard: one out_we/vector, SL cycles later");
    $display("=====================================================================");

    wload_phase=0; compute_phase=0; act_base=ABASE; out_base=OBASE;
    rst_n=0; repeat(3) @(negedge clk); #1 rst_n=1;

    sec_begin("T1", "weight address down-count + re-arm");
    wload_phase=0; @(negedge clk); #1;
    ck("armed_before", w_addr, ROWS-1);         // plain positive int (avoid signed 2-bit cast)
    $display("    armed w_addr before wload = %0d", w_addr);
    for (int k=0;k<ROWS;k++) begin
      wload_phase=1; #1;
      $display("    wload cyc %0d: w_addr=%0d wload=%0b w_rd_en=%0b", k, w_addr, wload, w_rd_en);
      ck($sformatf("w_addr[%0d]", k), w_addr, ROWS-1-k);
      ck($sformatf("wload_en[%0d]", k), wload, 1'b1);
      @(negedge clk);
    end
    wload_phase=0; @(negedge clk); #1;
    ck("rearm_after", w_addr, ROWS-1);
    ck("wload_low_idle", wload, 1'b0);
    $display("    re-armed w_addr after wload = %0d", w_addr);
    sec_end();

    sec_begin("T2", "activation address up-count from act_base");
    compute_phase=0; @(negedge clk); #1;
    ck("actcnt_reset", act_addr, act_base);
    for (int k=0;k<NV;k++) begin
      compute_phase=1; #1;
      $display("    compute cyc %0d: act_addr=0x%02h valid_in=%0b act_rd_en=%0b",
               k, act_addr, valid_in, act_rd_en);
      ck($sformatf("act_addr[%0d]", k), act_addr, A_ADDR_W'(ABASE+k));
      ck($sformatf("valid_in[%0d]", k), valid_in, 1'b1);
      @(negedge clk);
    end
    compute_phase=0; @(negedge clk); #1;
    ck("valid_low_idle", valid_in, 1'b0);
    sec_end();

    sec_begin("T3", "write-strobe scoreboard");
    // fully idle, reset counters
    #1 rst_n=0; repeat(3) @(negedge clk); #1 rst_n=1;
    compute_phase=0; obs_cnt=0;
    // run a timeline: compute burst of NV starting at cstart, observe strobes
    begin
      int cstart; cstart = 4;
      for (gcyc=0; gcyc < cstart + NV + SL + 4; gcyc++) begin
        @(negedge clk);
        compute_phase = (gcyc >= cstart && gcyc < cstart+NV) ? 1'b1 : 1'b0;
        #1;
        if (out_we) begin
          obs_g[obs_cnt]    = gcyc;
          obs_addr[obs_cnt] = out_addr;
          $display("    out_we @ sample %0d : out_addr=0x%02h", gcyc, out_addr);
          obs_cnt++;
        end
      end
      // exactly NV strobes
      ck("strobe_count", obs_cnt, NV);
      // each strobe i: address OBASE+i, timing cstart+i+SL
      for (int i=0;i<NV && i<obs_cnt;i++) begin
        ck($sformatf("strobe_addr[%0d]", i), obs_addr[i], O_ADDR_W'(OBASE+i));
        ck($sformatf("strobe_time[%0d]", i), obs_g[i],    cstart+i+SL);
      end
      $display("    %0d strobes observed, expected %0d; addresses OBASE..OBASE+%0d, each +SL late",
               obs_cnt, NV, NV-1);
    end
    sec_end();

    report_summary();
    $finish;
  end
endmodule
