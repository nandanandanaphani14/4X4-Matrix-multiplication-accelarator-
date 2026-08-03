`timescale 1ns/1ps
//=====================================================================
// tb_delay_pipe  --  unit test for delay_pipe.sv   (re-verification)
//
// DUT instances : DELAY=0 (wire), DELAY=1, DELAY=3   WIDTH=8
// Convention    : B - drive after posedge, sample at negedge, so a wire
//                 (DELAY=0) and a 1-deep register are distinguishable.
// Reference     : dout(m) == din(m - DELAY), every depth including 0.
//=====================================================================
module tb_delay_pipe;
  localparam int W = 8;
  logic clk = 0, rst_n;
  logic [W-1:0] din, dout0, dout1, dout3;
  always #5 clk = ~clk;

  delay_pipe #(.WIDTH(W), .DELAY(0)) u0 (.clk(clk), .rst_n(rst_n), .din(din), .dout(dout0));
  delay_pipe #(.WIDTH(W), .DELAY(1)) u1 (.clk(clk), .rst_n(rst_n), .din(din), .dout(dout1));
  delay_pipe #(.WIDTH(W), .DELAY(3)) u3 (.clk(clk), .rst_n(rst_n), .din(din), .dout(dout3));

  `include "tb_common.svh"

  logic [W-1:0] hist [0:2047];
  int j;

  initial begin
    TB = "tb_delay_pipe";
    $display("=====================================================================");
    $display(" %s  --  unit test for delay_pipe.sv   (re-verification)", TB);
    $display("=====================================================================");
    $display(" DUT instances : DELAY=0 (wire), DELAY=1, DELAY=3");
    $display(" WIDTH         : %0d bits", W);
    $display(" Convention    : B - drive after posedge, sample at negedge");
    $display("");
    $display(" TEST PLAN");
    $display("   T1  delay accuracy over a random stream, all three instances");
    $display("   T2  synchronous reset flushes DELAY>0, DELAY=0 unaffected");
    $display("   T3  a single pulse walks the pipe stage by stage after reset");
    $display("=====================================================================");

    din = 0; rst_n = 0;
    repeat (3) @(negedge clk); #1 rst_n = 1;

    sec_begin("T1", "delay accuracy, random stream");
    $display("     iter |  din | dout  (d0    d1    d3)   | expected (d0    d1    d3)");
    $display("    ------+------+--------------------------+--------------------------");
    for (j = 0; j < 40; j++) begin
      din = 8'($urandom); #1; hist[j] = din;
      $display("      %3d | 0x%02h |  0x%02h  0x%02h  0x%02h       |  0x%02h  0x%02h  0x%02h",
               j, din, dout0, dout1, dout3,
               hist[j], (j>=1)?hist[j-1]:8'h00, (j>=3)?hist[j-3]:8'h00);
      ck($sformatf("d0[%0d]", j), dout0, hist[j]);
      if (j >= 1) ck($sformatf("d1[%0d]", j), dout1, hist[j-1]);
      if (j >= 3) ck($sformatf("d3[%0d]", j), dout3, hist[j-3]);
      @(negedge clk);
    end
    $display("    note: DELAY=0 tracks din in the same iteration (it is a wire);");
    $display("          DELAY=1 lags by one iteration; DELAY=3 lags by three.");
    sec_end();

    sec_begin("T2", "synchronous reset flushes the pipe");
    rst_n = 0; repeat (4) @(negedge clk);
    din = 8'hFF; #1;
    $display("    driving din=0xFF and holding rst_n low for 4 clocks");
    $display("    after reset: dout_d0=0x%02h  dout_d1=0x%02h  dout_d3=0x%02h", dout0, dout1, dout3);
    $display("    DELAY=0 still shows 0xFF, as a wire must - it has no state to clear.");
    ck("rst_d0_wire", dout0, 8'hFF);
    ck("rst_d1",      dout1, 8'h00);
    ck("rst_d3",      dout3, 8'h00);
    sec_end();

    sec_begin("T3", "refill after reset: a pulse walks the pipe");
    @(negedge clk); #1 rst_n = 1; din = 0; @(negedge clk);
    din = 8'hA5; #1;
    $display("    offset 0 : din=0x%02h  d0=0x%02h  d1=0x%02h  d3=0x%02h", din, dout0, dout1, dout3);
    ck("walk0_d0", dout0, 8'hA5); ck("walk0_d3", dout3, 8'h00);
    @(negedge clk); din = 8'h00; #1;
    $display("    offset 1 : din=0x%02h  d0=0x%02h  d1=0x%02h  d3=0x%02h", din, dout0, dout1, dout3);
    ck("walk1_d1", dout1, 8'hA5); ck("walk1_d3", dout3, 8'h00);
    @(negedge clk); #1;
    $display("    offset 2 : din=0x%02h  d0=0x%02h  d1=0x%02h  d3=0x%02h", din, dout0, dout1, dout3);
    ck("walk2_d3", dout3, 8'h00);
    @(negedge clk); #1;
    $display("    offset 3 : din=0x%02h  d0=0x%02h  d1=0x%02h  d3=0x%02h", din, dout0, dout1, dout3);
    ck("walk3_d3", dout3, 8'hA5);
    $display("    the 0xA5 pulse reached DELAY=3 exactly 3 offsets after it was driven.");
    sec_end();

    report_summary();
    $finish;
  end
endmodule
