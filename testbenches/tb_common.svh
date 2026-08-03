//=====================================================================
// tb_common.svh  --  shared reporting harness for the re-verification
// testbenches.  `include this inside a module.  It provides:
//
//   checks / errors                  running totals
//   ck(tag, got, exp)                one hex-reported check
//   ckd(tag, got, exp)               one decimal-reported check (signed)
//   sec_begin(code, desc)            open a section, print its banner
//   sec_end()                        close a section, print its tally
//   print_header(desc, plan)         top banner + test plan block
//   report_summary()                 section-summary table + TOTALS + RESULT
//
// The owning module must declare `string TB;` before including, OR set
// TB in its initial block (this file declares it).
//=====================================================================
  string   TB;
  int      checks = 0, errors = 0;
  int      s_base_c, s_base_e, nsec = 0;
  string   scode [0:31], sdesc [0:31];
  int      schk  [0:31], serr  [0:31];

  task automatic sec_begin(string code, string desc);
    s_base_c = checks; s_base_e = errors;
    scode[nsec] = code; sdesc[nsec] = desc;
    $display("");
    $display("  -----------------------------------------------------------------");
    $display("  %s : %s", code, desc);
    $display("  -----------------------------------------------------------------");
  endtask

  task automatic sec_end();
    int dc, de; dc = checks - s_base_c; de = errors - s_base_e;
    schk[nsec] = dc; serr[nsec] = de;
    $display("    %s ends: %0d checks, %0d errors  [%s]", scode[nsec], dc, de,
             (de==0) ? "PASS" : "FAIL");
    nsec++;
  endtask

  task automatic ck(string tag, logic [127:0] got, logic [127:0] exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("    [MISMATCH] %-22s got=0x%0h exp=0x%0h", tag, got, exp);
    end
  endtask

  task automatic ckd(string tag, longint got, longint exp);
    checks++;
    if (got !== exp) begin
      errors++;
      $display("    [MISMATCH] %-22s got=%0d exp=%0d", tag, got, exp);
    end
  endtask

  task automatic report_summary();
    $display("");
    $display("  =================================================================");
    $display("   SECTION SUMMARY : %s", TB);
    $display("  =================================================================");
    $display("   SEC    DESCRIPTION                                     CHECKS  ERRORS  STATUS");
    $display("   ------ ---------------------------------------------- ------- -------  ------");
    for (int i = 0; i < nsec; i++)
      $display("   %-6s %-44s %7d %7d  %s", scode[i], sdesc[i], schk[i], serr[i],
               (serr[i]==0) ? "PASS" : "FAIL");
    $display("   ------ ---------------------------------------------- ------- -------");
    $display("   TOTAL                                                 %7d %7d", checks, errors);
    $display("  =================================================================");
    $display("   TOTALS: %0d checks, %0d errors", checks, errors);
    $display("   simulated time : %0d ns", $time);
    $display("   RESULT: %s - %s", (errors==0) ? "PASS" : "FAIL", TB);
    $display("  =================================================================");
  endtask
