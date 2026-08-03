`timescale 1ns/1ps
//=====================================================================
// tb_processing_element  --  DUT: processing_element (MAC.sv)
//
// Convention A (registered outputs): drive inputs just after a posedge,
// let the NEXT posedge consume them, then sample.  A cycle-accurate
// reference model of the four PE registers is compared every cycle.
// Directed constants are hand-computed and owe nothing to the model.
//=====================================================================
module tb_processing_element;
  logic               clk = 0, rst_n;
  logic               wload, valid_in;
  logic signed [7:0]  a_in;
  logic signed [31:0] psum_in;
  logic signed [7:0]  a_out;
  logic               valid_out;
  logic signed [31:0] psum_out;
  always #5 clk = ~clk;

  processing_element dut (
    .clk(clk), .rst_n(rst_n), .wload(wload), .valid_in(valid_in),
    .a_in(a_in), .a_out(a_out), .valid_out(valid_out),
    .psum_in(psum_in), .psum_out(psum_out));

  `include "tb_common.svh"

  // Reference model registers
  logic signed [7:0]  m_weight, m_a;
  logic               m_valid;
  logic signed [31:0] m_psum;
  int    trace_on = 0;

  // Drive one cycle: apply inputs, advance model, consume at posedge, check.
  task automatic step(logic w, logic v, logic signed [7:0] a, logic signed [31:0] p);
    logic signed [7:0]  n_weight;
    logic signed [31:0] n_psum, exp_psum_out;
    #1;
    wload = w; valid_in = v; a_in = a; psum_in = p;
    n_weight = w ? p[7:0] : m_weight;           // product uses OLD weight
    n_psum   = v ? (p + (m_weight * a)) : p;
    @(posedge clk);
    m_weight = n_weight; m_a = a; m_valid = v; m_psum = n_psum;
    #1;
    exp_psum_out = w ? 32'(m_weight) : m_psum;
    if (trace_on)
      $display("    w=%0b v=%0b a=%4d psum_in=%6d | a_out=%4d valid_out=%0b psum_out=%0d (exp %0d)",
               w, v, a, p, a_out, valid_out, psum_out, exp_psum_out);
    ckd("a_out",     a_out,     m_a);
    ckd("valid_out", valid_out, m_valid);
    ckd("psum_out",  psum_out,  exp_psum_out);
  endtask

  initial begin
    TB = "tb_processing_element";
    $display("=====================================================================");
    $display(" %s  --  DUT: processing_element (MAC.sv)", TB);
    $display("=====================================================================");
    $display(" Convention    : A - drive after posedge, consume at next posedge, sample");
    $display(" Reference     : cycle-accurate model of weight_q/a_q/valid_q/psum_q");
    $display("");
    $display(" TEST PLAN");
    $display("   T1  directed vectors with hand-computed constants");
    $display("   T2  500-cycle random stream vs the reference model");
    $display("   T3  reset mid-stream clears registers; correct after release");
    $display("=====================================================================");

    wload=0; valid_in=0; a_in=0; psum_in=0; rst_n=0;
    m_weight=0; m_a=0; m_valid=0; m_psum=0;
    repeat (3) @(posedge clk); #1 rst_n=1;

    sec_begin("T1", "directed vectors, hand-computed constants");
    trace_on = 1;
    step(1,0,0,3);      $display("      -> loaded weight = 3");
    step(0,1,5,100);    ckd("directed_100+3*5=115", m_psum, 115);
    step(1,0,0,-4);     $display("      -> loaded weight = -4");
    step(0,1,7,0);      ckd("directed_(-4)*7=-28",   m_psum, -28);
    step(1,0,0,-128);   $display("      -> loaded weight = -128");
    step(0,1,-128,0);   ckd("directed_(-128)^2=16384", m_psum, 16384);
    step(1,0,0,127);    $display("      -> loaded weight = 127");
    step(0,1,-2,50);    ckd("directed_50+127*(-2)=-204", m_psum, -204);
    step(0,0,9,32'sh1234_5678); ckd("bypass_valid0_pass", m_psum, 32'sh1234_5678);
    step(1,0,0,-3);     ck ("wload_signext_-3=FFFFFFFD", psum_out, 32'shFFFF_FFFD);
    trace_on = 0;
    sec_end();

    sec_begin("T2", "500-cycle random stream vs reference model");
    for (int i = 0; i < 500; i++) begin
      if (i < 4) trace_on = 1; else trace_on = 0;
      step($urandom_range(0,1), $urandom_range(0,1), 8'($urandom), 32'($urandom));
    end
    $display("    (500 random cycles, a_out/valid_out/psum_out checked each cycle)");
    sec_end();

    sec_begin("T3", "reset mid-stream then correct after release");
    #1 rst_n=0; @(posedge clk); #1;
    m_weight=0; m_a=0; m_valid=0; m_psum=0;
    ckd("rst_a_out",    a_out, 0);
    ckd("rst_valid",    valid_out, 0);
    ckd("rst_psum_out", psum_out, 0);
    $display("    after reset: a_out=%0d valid_out=%0b psum_out=%0d", a_out, valid_out, psum_out);
    #1 rst_n=1;
    trace_on = 1;
    step(1,0,0,42);
    step(0,1,2,10);  ckd("post_reset_10+42*2=94", m_psum, 94);
    trace_on = 0;
    sec_end();

    report_summary();
    $finish;
  end
endmodule
