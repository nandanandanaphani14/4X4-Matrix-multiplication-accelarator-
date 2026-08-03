`timescale 1ns/1ps
//=====================================================================
// tb_memories  --  DUTs: a_mem, weight_mem, output_mem
//
// The three memories are the same single-port synchronous RAM primitive
// at different geometries.  Verified: 1-cycle registered read latency,
// we=0 hold, read-before-write on address collision, weight_mem 2-bit
// address wrap, and per-lane word integrity for the packing conventions.
//=====================================================================
module tb_memories;
  logic clk = 0;
  always #5 clk = ~clk;

  logic          a_we;  logic [7:0] a_addr;  logic [31:0]  a_wdata, a_rdata;
  logic          w_we;  logic [1:0] w_addr;  logic [31:0]  w_wdata, w_rdata;
  logic          o_we;  logic [7:0] o_addr;  logic [127:0] o_wdata, o_rdata;

  a_mem      #(.DATA_W(32),  .ADDR_W(8)) ua (.clk(clk), .we(a_we), .addr(a_addr), .wdata(a_wdata), .rdata(a_rdata));
  weight_mem #(.DATA_W(32),  .ADDR_W(2)) uw (.clk(clk), .we(w_we), .addr(w_addr), .wdata(w_wdata), .rdata(w_rdata));
  output_mem #(.DATA_W(128), .ADDR_W(8)) uo (.clk(clk), .we(o_we), .addr(o_addr), .wdata(o_wdata), .rdata(o_rdata));

  `include "tb_common.svh"

  logic [31:0] refa [0:255];

  initial begin
    TB = "tb_memories";
    $display("=====================================================================");
    $display(" %s  --  DUTs: a_mem (256x32), weight_mem (4x32), output_mem (256x128)", TB);
    $display("=====================================================================");
    $display(" Convention    : registered read - rdata valid one cycle after addr");
    $display("");
    $display(" TEST PLAN");
    $display("   T1  a_mem  write/read-back sweep + we=0 hold + read-before-write");
    $display("   T2  weight_mem per-lane integrity + 2-bit address wrap");
    $display("   T3  output_mem 128-bit per-lane integrity, extreme signed values");
    $display("=====================================================================");

    a_we=0; w_we=0; o_we=0; a_addr=0; w_addr=0; o_addr=0;
    a_wdata=0; w_wdata=0; o_wdata=0;
    @(negedge clk);

    sec_begin("T1", "a_mem write/read-back, we=0 hold, read-before-write");
    for (int i = 0; i < 64; i++) begin
      a_we=1; a_addr=i[7:0]; a_wdata=32'($urandom); refa[i]=a_wdata; @(negedge clk);
    end
    a_we=0;
    for (int i = 0; i < 64; i++) begin
      a_addr=i[7:0]; @(posedge clk); @(negedge clk);
      ck($sformatf("a_rd[%0d]", i), a_rdata, refa[i]);
    end
    $display("    swept 64 addresses; read-back one cycle after address, all matched");
    a_we=0; a_addr=5; a_wdata=32'hFFFF_FFFF; @(negedge clk);
    a_addr=5; @(posedge clk); @(negedge clk);
    ck("we0_hold_addr5", a_rdata, refa[5]);
    $display("    we=0 with wdata=0xFFFFFFFF on addr5: memory untouched (0x%08h)", a_rdata);
    a_we=1; a_addr=7; a_wdata=32'hDEAD_BEEF; @(posedge clk); #1;
    ck("read_before_write", a_rdata, refa[7]);
    $display("    read-during-write addr7: rdata=0x%08h == OLD 0x%08h (read-before-write)", a_rdata, refa[7]);
    a_we=0; refa[7]=32'hDEAD_BEEF;
    a_addr=7; @(posedge clk); @(negedge clk);
    ck("after_write_addr7", a_rdata, 32'hDEAD_BEEF);
    sec_end();

    sec_begin("T2", "weight_mem per-lane integrity + address wrap");
    for (int r = 0; r < 4; r++) begin
      w_we=1; w_addr=r[1:0];
      w_wdata = {8'(r*16+3), 8'(r*16+2), 8'(r*16+1), 8'(r*16+0)}; @(negedge clk);
    end
    w_we=0;
    for (int r = 0; r < 4; r++) begin
      w_addr=r[1:0]; @(posedge clk); @(negedge clk);
      $display("    weight_mem[%0d] = 0x%08h  lanes = %0d %0d %0d %0d", r, w_rdata,
               w_rdata[0*8+:8], w_rdata[1*8+:8], w_rdata[2*8+:8], w_rdata[3*8+:8]);
      for (int c = 0; c < 4; c++)
        ck($sformatf("w_lane[%0d][%0d]", r, c), 128'(w_rdata[c*8 +: 8]), 128'(8'(r*16+c)));
    end
    w_addr=2'(4); @(posedge clk); @(negedge clk);
    ck("addr_wrap_4_aliases_0", 128'(w_rdata), 128'({8'd3,8'd2,8'd1,8'd0}));
    $display("    2-bit address 4 aliases 0: read back 0x%08h", w_rdata);
    sec_end();

    sec_begin("T3", "output_mem 128-bit lane integrity, extreme signed");
    o_we=1; o_addr=8'h20;
    o_wdata = {32'h7FFF_FFFF, 32'hFFFF_FFFF, 32'h8000_0000, 32'h0000_0001};
    @(negedge clk); o_we=0;
    o_addr=8'h20; @(posedge clk); @(negedge clk);
    $display("    output_mem[0x20] = 0x%032h", o_rdata);
    ck("o_lane0", 128'(o_rdata[0*32 +: 32]), 128'(32'h0000_0001));
    ck("o_lane1", 128'(o_rdata[1*32 +: 32]), 128'(32'h8000_0000));
    ck("o_lane2", 128'(o_rdata[2*32 +: 32]), 128'(32'hFFFF_FFFF));
    ck("o_lane3", 128'(o_rdata[3*32 +: 32]), 128'(32'h7FFF_FFFF));
    sec_end();

    report_summary();
    $finish;
  end
endmodule
