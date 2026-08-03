`timescale 1ns/1ps
//=====================================================================
// tb_output_deskew_buffer  --  DUT: output_deskew_buffer (output_skewbuf.sv)
//
// Convention B.  Column c is delayed by COLS-1-c.  The key test feeds the
// staircase the array emits and requires all COLS columns to emerge on a
// single cycle, and to be empty on every cycle before that.
//=====================================================================
module tb_output_deskew_buffer;
  localparam int COLS = 4, W = 32;
  logic clk = 0, rst_n;
  logic signed [W-1:0] psum_in     [0:COLS-1];
  logic signed [W-1:0] aligned_out [0:COLS-1];
  always #5 clk = ~clk;

  output_deskew_buffer #(.COLS(COLS), .WIDTH(W)) dut (
    .clk(clk), .rst_n(rst_n), .psum_in(psum_in), .aligned_out(aligned_out));

  `include "tb_common.svh"

  logic signed [W-1:0] hist [0:COLS-1][0:511];
  int j, c;

  initial begin
    TB = "tb_output_deskew_buffer";
    $display("=====================================================================");
    $display(" %s  --  DUT: output_deskew_buffer (output_skewbuf.sv)", TB);
    $display("=====================================================================");
    $display(" COLS=%0d WIDTH=%0d  column c delayed by COLS-1-c  (Convention B)", COLS, W);
    $display("");
    $display(" TEST PLAN");
    $display("   T1  random per-column stream: column c delayed by COLS-1-c");
    $display("   T2  staircase in -> single-cycle aligned out; empty before that");
    $display("=====================================================================");

    for (c=0;c<COLS;c++) psum_in[c]=0;
    rst_n=0; repeat(3) @(negedge clk); #1 rst_n=1;

    sec_begin("T1", "random stream, per-column delay = COLS-1-c");
    for (j=0;j<120;j++) begin
      for (c=0;c<COLS;c++) psum_in[c]=$random; #1;
      for (c=0;c<COLS;c++) hist[c][j]=psum_in[c];
      for (c=0;c<COLS;c++) if (j >= (COLS-1-c))
        ck($sformatf("col[%0d][%0d]", c, j), aligned_out[c], hist[c][j-(COLS-1-c)]);
      @(negedge clk);
    end
    $display("    120 cycles: aligned_out[c] equals psum_in[c] delayed by COLS-1-c");
    sec_end();

    sec_begin("T2", "staircase alignment + empty-before check");
    #1 rst_n=0; @(negedge clk); #1 rst_n=1;
    for (c=0;c<COLS;c++) psum_in[c]=0; @(negedge clk);
    // present each column c one cycle later than column 0 (the array's staircase)
    psum_in[0]=32'sh0000_0001;                          #1; @(negedge clk);
    psum_in[0]=0; psum_in[1]=32'sh8000_0000;            #1; @(negedge clk);
    psum_in[1]=0; psum_in[2]=32'shFFFF_FFFF;            #1; @(negedge clk);
    psum_in[2]=0; psum_in[3]=32'sh7FFF_FFFF;            #1;
    $display("    aligned_out = 0x%08h 0x%08h 0x%08h 0x%08h",
             aligned_out[0], aligned_out[1], aligned_out[2], aligned_out[3]);
    ck("align_c0", aligned_out[0], 32'sh0000_0001);
    ck("align_c1", aligned_out[1], 32'sh8000_0000);
    ck("align_c2", aligned_out[2], 32'shFFFF_FFFF);
    ck("align_c3", aligned_out[3], 32'sh7FFF_FFFF);
    $display("    all four columns (incl. extreme signed values) aligned on ONE cycle");
    @(negedge clk); psum_in[3]=0; #1;
    ck("empty_c0", aligned_out[0], 0);
    ck("empty_c1", aligned_out[1], 0);
    ck("empty_c2", aligned_out[2], 0);
    ck("empty_c3", aligned_out[3], 0);
    $display("    the cycle after alignment the bus is empty again");
    sec_end();

    report_summary();
    $finish;
  end
endmodule
