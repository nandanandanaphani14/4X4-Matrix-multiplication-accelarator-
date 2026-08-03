`timescale 1ns/1ps
//=====================================================================
// tb_systolic_array  --  DUT: systolic_array (array.sv)
//
// First fully algorithmic golden model.  A random NON-SYMMETRIC 4x4
// weight matrix is shifted in bottom-first, then activation vectors are
// streamed with manual skew (row r delayed by r).  Every column's bottom
// output is compared against C = A x W computed by a plain nested loop.
//
// Because W is random and non-symmetric, any permutation of the weight
// rows would fail -> this proves the bottom-first load rule.
//
// Cycle model: inputs applied at negedge, consumed at the next posedge
// (= cycle cyc); registered outputs sampled just after.  Column c of the
// vector whose row 0 is consumed at cyc p0 is observable after posedge
// p0 + (ROWS-1) + c.
//=====================================================================
module tb_systolic_array;
  localparam int ROWS = 4, COLS = 4;
  localparam int BASE = 10, NVEC = 6;
  localparam int T    = BASE + NVEC + ROWS + COLS + 6;

  logic clk = 0, rst_n, wload;
  logic signed [7:0]  a_in_left     [0:ROWS-1];
  logic               valid_in_left [0:ROWS-1];
  logic signed [31:0] psum_in_top   [0:COLS-1];
  logic signed [31:0] psum_out_bottom [0:COLS-1];
  always #5 clk = ~clk;

  systolic_array #(.ROWS(ROWS), .COLS(COLS)) dut (
    .clk(clk), .rst_n(rst_n), .wload(wload),
    .a_in_left(a_in_left), .valid_in_left(valid_in_left),
    .psum_in_top(psum_in_top), .psum_out_bottom(psum_out_bottom));

  `include "tb_common.svh"

  int Wt[0:ROWS-1][0:COLS-1], Avec[0:NVEC-1][0:ROWS-1], Cexp[0:NVEC-1][0:COLS-1];
  int cyc, r, c, i, acc, nresults;

  initial begin
    TB = "tb_systolic_array";
    for (r=0;r<ROWS;r++) for (c=0;c<COLS;c++) Wt[r][c]   = $signed(8'($urandom));
    for (i=0;i<NVEC;i++) for (r=0;r<ROWS;r++) Avec[i][r] = $signed(8'($urandom));
    for (i=0;i<NVEC;i++) for (c=0;c<COLS;c++) begin
      acc=0; for (r=0;r<ROWS;r++) acc += Avec[i][r]*Wt[r][c]; Cexp[i][c]=acc;
    end

    $display("=====================================================================");
    $display(" %s  --  DUT: systolic_array (array.sv)", TB);
    $display("=====================================================================");
    $display(" ROWS=%0d COLS=%0d   golden C = A x W (nested-loop reference)", ROWS, COLS);
    $display(" Weights loaded bottom-first; W is random + non-symmetric.");
    $display("");
    $display(" TEST PLAN");
    $display("   T1  load weights, stream %0d vectors, check every dot product", NVEC);
    $display("   T2  negative: array drains to 0 after the last valid input");
    $display("=====================================================================");
    $display(" Weight matrix W (row r, col c):");
    for (r=0;r<ROWS;r++)
      $display("   W[%0d] = %5d %5d %5d %5d", r, Wt[r][0], Wt[r][1], Wt[r][2], Wt[r][3]);
    $display(" Expected results C[i] = A[i] x W:");
    for (i=0;i<NVEC;i++)
      $display("   C[%0d] = %6d %6d %6d %6d", i, Cexp[i][0], Cexp[i][1], Cexp[i][2], Cexp[i][3]);

    wload=0;
    for (r=0;r<ROWS;r++) begin a_in_left[r]=0; valid_in_left[r]=0; end
    for (c=0;c<COLS;c++) psum_in_top[c]=0;
    rst_n=0; repeat(3) @(negedge clk); #1 rst_n=1;

    sec_begin("T1", "load + stream, per-column dot-product check");
    nresults = 0;
    for (cyc=0; cyc<T; cyc++) begin
      @(negedge clk);
      if (cyc < ROWS) begin
        wload = 1'b1;
        for (c=0;c<COLS;c++) psum_in_top[c] = 32'(Wt[ROWS-1-cyc][c]);
        for (r=0;r<ROWS;r++) begin a_in_left[r]=0; valid_in_left[r]=0; end
        if (cyc==0) $display("    WLOAD: driving weight rows bottom-first (row %0d first)", ROWS-1);
      end
      else begin
        wload = 1'b0;
        for (c=0;c<COLS;c++) psum_in_top[c] = 0;
        for (r=0;r<ROWS;r++) begin
          i = cyc - BASE - r;
          if (i>=0 && i<NVEC) begin a_in_left[r]=8'(Avec[i][r]); valid_in_left[r]=1'b1; end
          else                begin a_in_left[r]=0;              valid_in_left[r]=1'b0; end
        end
      end
      @(posedge clk); #1;
      for (c=0;c<COLS;c++) begin
        i = cyc - (BASE + (ROWS-1) + c);
        if (i>=0 && i<NVEC) begin
          if (c==0)
            $display("    cyc %0d: C[%0d] bottom = %6d %6d %6d %6d (exp %6d %6d %6d %6d)",
                     cyc, i, psum_out_bottom[0], psum_out_bottom[1], psum_out_bottom[2], psum_out_bottom[3],
                     Cexp[i][0], Cexp[i][1], Cexp[i][2], Cexp[i][3]);
          ck($sformatf("C[%0d][%0d]", i, c), psum_out_bottom[c], 32'(Cexp[i][c]));
          nresults++;
        end
      end
    end
    $display("    checked %0d dot-product lanes across %0d vectors", nresults, NVEC);
    sec_end();

    sec_begin("T2", "negative: array drains to 0 after last valid");
    for (r=0;r<ROWS;r++) valid_in_left[r]=0;
    repeat (ROWS+2) @(negedge clk);
    @(posedge clk); #1;
    for (c=0;c<COLS;c++) ck($sformatf("drained[%0d]", c), psum_out_bottom[c], 0);
    $display("    bottom bus = %0d %0d %0d %0d (all zero)",
             psum_out_bottom[0], psum_out_bottom[1], psum_out_bottom[2], psum_out_bottom[3]);
    sec_end();

    report_summary();
    $finish;
  end
endmodule
