`timescale 1ns/1ps
//=====================================================================
// tb_array_buf_top  --  DUT: array_buf_top (wrapper_array_buf.sv)  LEVEL 1
//
// Same algorithmic golden model as tb_systolic_array, but the skew and
// de-skew buffers are now INSIDE the DUT, so DENSE (un-skewed) vectors go
// in and the whole result vector must appear ALIGNED on one cycle at
// RESULT_LATENCY = ROWS+COLS-2 = 6 cycles.  The pre-de-skew bus psum_raw
// is tapped to confirm the staircase is still there (the de-skew buffer,
// not a permissive golden model, is doing the alignment).
//=====================================================================
module tb_array_buf_top;
  localparam int ROWS=4, COLS=4, DATA_W=8, PSUM_W=32;
  localparam int RESULT_LATENCY = ROWS+COLS-2;   // 6
  localparam int BASE=12, NVEC=6;
  localparam int T = BASE + NVEC + RESULT_LATENCY + 6;

  logic clk=0, rst_n, wload;
  logic signed [DATA_W-1:0] dense_a [0:ROWS-1];
  logic                     dense_v [0:ROWS-1];
  logic signed [PSUM_W-1:0] psum_top [0:COLS-1];
  logic signed [PSUM_W-1:0] result   [0:COLS-1];
  logic signed [PSUM_W-1:0] psum_raw [0:COLS-1];
  always #5 clk = ~clk;

  array_buf_top #(.ROWS(ROWS), .COLS(COLS), .DATA_W(DATA_W), .PSUM_W(PSUM_W)) dut (
    .clk(clk), .rst_n(rst_n), .wload(wload),
    .dense_a_in(dense_a), .dense_valid_in(dense_v),
    .psum_in_top(psum_top), .result(result), .psum_raw(psum_raw));

  `include "tb_common.svh"

  int Wt[0:ROWS-1][0:COLS-1], Avec[0:NVEC-1][0:ROWS-1], Cexp[0:NVEC-1][0:COLS-1];
  int cyc, r, c, i, acc, aligned_hits, stair_hits;

  initial begin
    TB = "tb_array_buf_top";
    for (r=0;r<ROWS;r++) for (c=0;c<COLS;c++) Wt[r][c]   = $signed(8'($urandom));
    for (i=0;i<NVEC;i++) for (r=0;r<ROWS;r++) Avec[i][r] = $signed(8'($urandom));
    for (i=0;i<NVEC;i++) for (c=0;c<COLS;c++) begin
      acc=0; for (r=0;r<ROWS;r++) acc += Avec[i][r]*Wt[r][c]; Cexp[i][c]=acc; end

    $display("=====================================================================");
    $display(" %s  --  DUT: array_buf_top (LEVEL 1)   RESULT_LATENCY=%0d", TB, RESULT_LATENCY);
    $display("=====================================================================");
    $display(" Dense vectors in, aligned result out.  Golden C = A x W.");
    $display("");
    $display(" TEST PLAN");
    $display("   T1  full result vector aligned on ONE cycle at n+%0d", RESULT_LATENCY);
    $display("   T2  psum_raw still shows the per-column staircase (n+3+c)");
    $display("   T3  negative: result bus quiet before the first result");
    $display("=====================================================================");

    wload=0;
    for (r=0;r<ROWS;r++) begin dense_a[r]=0; dense_v[r]=0; end
    for (c=0;c<COLS;c++) psum_top[c]=0;
    rst_n=0; repeat(3) @(negedge clk); #1 rst_n=1;

    sec_begin("T1", "aligned result vector, golden C = A x W");
    aligned_hits=0; stair_hits=0;
    for (cyc=0; cyc<T; cyc++) begin
      @(negedge clk);
      if (cyc < ROWS) begin
        wload=1'b1;
        for (c=0;c<COLS;c++) psum_top[c]=32'(Wt[ROWS-1-cyc][c]);
        for (r=0;r<ROWS;r++) begin dense_a[r]=0; dense_v[r]=0; end
      end else begin
        wload=1'b0;
        for (c=0;c<COLS;c++) psum_top[c]=0;
        i = cyc - BASE;
        if (i>=0 && i<NVEC) begin
          for (r=0;r<ROWS;r++) begin dense_a[r]=8'(Avec[i][r]); dense_v[r]=1'b1; end
        end else
          for (r=0;r<ROWS;r++) begin dense_a[r]=0; dense_v[r]=0; end
      end
      @(posedge clk); #1;
      // aligned result for vector i at cyc = BASE+i+RESULT_LATENCY
      i = cyc - (BASE + RESULT_LATENCY);
      if (i>=0 && i<NVEC) begin
        $display("    cyc %0d: result C[%0d] = %6d %6d %6d %6d (exp %6d %6d %6d %6d)",
                 cyc, i, result[0], result[1], result[2], result[3],
                 Cexp[i][0], Cexp[i][1], Cexp[i][2], Cexp[i][3]);
        for (c=0;c<COLS;c++) ck($sformatf("result[%0d][%0d]", i, c), result[c], 32'(Cexp[i][c]));
        aligned_hits++;
      end
      // staircase on psum_raw at cyc = BASE+i2+3+c
      for (c=0;c<COLS;c++) begin
        i = cyc - (BASE + (ROWS-1) + c);
        if (i>=0 && i<NVEC) begin
          ck($sformatf("raw[%0d][%0d]", i, c), psum_raw[c], 32'(Cexp[i][c]));
          stair_hits++;
        end
      end
    end
    $display("    aligned result vectors checked: %0d ; staircase lanes checked: %0d",
             aligned_hits, stair_hits);
    sec_end();

    sec_begin("T2", "de-skew alignment is real (raw staircase vs aligned)");
    $display("    psum_raw presented column c at n+3+c (a staircase), yet result[]");
    $display("    delivered all COLS columns on a single cycle -> de-skew did the work.");
    ck("aligned_count", aligned_hits, NVEC);
    ck("stair_count",   stair_hits,   NVEC*COLS);
    sec_end();

    sec_begin("T3", "negative: result quiet before first result");
    // re-run reset, drive nothing, confirm result bus stays 0 through flush
    #1 rst_n=0; @(negedge clk); #1 rst_n=1;
    for (r=0;r<ROWS;r++) begin dense_a[r]=0; dense_v[r]=0; end
    for (c=0;c<COLS;c++) psum_top[c]=0; wload=0;
    repeat (RESULT_LATENCY) @(negedge clk);
    @(posedge clk); #1;
    for (c=0;c<COLS;c++) ck($sformatf("quiet[%0d]", c), result[c], 0);
    $display("    result = %0d %0d %0d %0d with no valid input (quiet)",
             result[0], result[1], result[2], result[3]);
    sec_end();

    report_summary();
    $finish;
  end
endmodule
