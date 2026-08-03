`timescale 1ns/1ps
//=====================================================================
// tb_input_skew_buffer  --  DUT: input_skew_buffer (input_buf.sv)
//
// Convention B.  Row r must be delayed by exactly r clocks and the valid
// bit must travel with its data.  T2 walks one dense vector through as a
// diagonal wavefront.
//=====================================================================
module tb_input_skew_buffer;
  localparam int ROWS = 4, W = 8;
  logic clk = 0, rst_n;
  logic signed [W-1:0] dense_a [0:ROWS-1];
  logic                dense_v [0:ROWS-1];
  logic signed [W-1:0] skew_a  [0:ROWS-1];
  logic                skew_v  [0:ROWS-1];
  always #5 clk = ~clk;

  input_skew_buffer #(.ROWS(ROWS), .WIDTH(W)) dut (
    .clk(clk), .rst_n(rst_n),
    .dense_a_in(dense_a), .dense_valid_in(dense_v),
    .skew_a_out(skew_a),  .skew_valid_out(skew_v));

  `include "tb_common.svh"

  logic signed [W-1:0] ah [0:ROWS-1][0:511];
  logic                vh [0:ROWS-1][0:511];
  int j, r;

  initial begin
    TB = "tb_input_skew_buffer";
    $display("=====================================================================");
    $display(" %s  --  DUT: input_skew_buffer (input_buf.sv)", TB);
    $display("=====================================================================");
    $display(" ROWS=%0d WIDTH=%0d  Convention B (drive after posedge, sample negedge)", ROWS, W);
    $display("");
    $display(" TEST PLAN");
    $display("   T1  random stream: row r delayed by r; valid travels with data");
    $display("   T2  one dense vector emerges as a diagonal wavefront");
    $display("=====================================================================");

    for (r=0;r<ROWS;r++) begin dense_a[r]=0; dense_v[r]=0; end
    rst_n=0; repeat(3) @(negedge clk); #1 rst_n=1;

    sec_begin("T1", "random stream, per-row delay = r");
    for (j=0;j<120;j++) begin
      for (r=0;r<ROWS;r++) begin dense_a[r]=8'($urandom); dense_v[r]=1'($urandom); end
      #1;
      for (r=0;r<ROWS;r++) begin ah[r][j]=dense_a[r]; vh[r][j]=dense_v[r]; end
      for (r=0;r<ROWS;r++) if (j>=r) begin
        ck($sformatf("a[%0d][%0d]", r, j), 32'(skew_a[r]), 32'(ah[r][j-r]));
        ck($sformatf("v[%0d][%0d]", r, j), 32'(skew_v[r]), 32'(vh[r][j-r]));
      end
      @(negedge clk);
    end
    $display("    120 cycles: skew_a[r]/skew_v[r] each equal their dense input delayed by r");
    sec_end();

    sec_begin("T2", "single dense vector -> diagonal wavefront");
    #1 rst_n=0; @(negedge clk); #1 rst_n=1;
    for (r=0;r<ROWS;r++) begin dense_a[r]=0; dense_v[r]=0; end
    @(negedge clk);
    dense_a[0]=11; dense_a[1]=22; dense_a[2]=33; dense_a[3]=44;
    for (r=0;r<ROWS;r++) dense_v[r]=1; #1;
    $display("    present [11,22,33,44] valid=1 on one cycle:");
    $display("    off0: skew_a=%0d %0d %0d %0d  skew_v=%0b %0b %0b %0b",
             skew_a[0],skew_a[1],skew_a[2],skew_a[3], skew_v[0],skew_v[1],skew_v[2],skew_v[3]);
    ck("wf0_row0_a", 32'(skew_a[0]), 11); ck("wf0_row0_v", 32'(skew_v[0]), 1);
    ck("wf0_row3_quiet", 32'(skew_v[3]), 0);
    @(negedge clk);
    for (r=0;r<ROWS;r++) dense_v[r]=0;
    for (r=0;r<ROWS;r++) dense_a[r]=0; #1;
    $display("    off1: skew_a=%0d %0d %0d %0d  skew_v=%0b %0b %0b %0b",
             skew_a[0],skew_a[1],skew_a[2],skew_a[3], skew_v[0],skew_v[1],skew_v[2],skew_v[3]);
    ck("wf1_row1_a", 32'(skew_a[1]), 22); ck("wf1_row1_v", 32'(skew_v[1]), 1);
    ck("wf1_row0_gone", 32'(skew_v[0]), 0);
    @(negedge clk); #1;
    $display("    off2: skew_a[2]=%0d", skew_a[2]);
    ck("wf2_row2_a", 32'(skew_a[2]), 33);
    @(negedge clk); #1;
    $display("    off3: skew_a[3]=%0d skew_v[3]=%0b", skew_a[3], skew_v[3]);
    ck("wf3_row3_a", 32'(skew_a[3]), 44); ck("wf3_row3_v", 32'(skew_v[3]), 1);
    $display("    the vector formed a clean diagonal: row r appeared at offset r.");
    sec_end();

    report_summary();
    $finish;
  end
endmodule
