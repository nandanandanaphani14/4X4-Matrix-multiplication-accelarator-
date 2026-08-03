# TB Reports Folder Index (`SIMPLE_ACCEL_TB_REPORTS`)

The **original** verification transcripts and report (QuestaSim 2021.1, run 2026-07-30, 13/13 PASS,
3 902 checks). For the **independent re-verification** performed later, see
[`../../verification_recheck/`](../../verification_recheck/index.md).

| Artifact | Content |
|----------|---------|
| [verification_report.md](verification_report.md) | full strategy, results table, defects, coverage boundaries |
| [regression_summary.txt](regression_summary.txt) | machine-readable roll-up |
| [compile.log](compile.log) | compile transcript |
| `tb_*.log` | one transcript per original testbench |

Map to context chunks: strategy & coverage → [14_coverage_boundaries](../../context_mkdwn/14_coverage_boundaries.md);
latency constants checked → [12_dataflow_and_timing](../../context_mkdwn/12_dataflow_and_timing.md);
per-DUT detail → chunks [01](../../context_mkdwn/01_processing_element.md)–[11](../../context_mkdwn/11_wrapper_L3_system_top.md).

_This index.md is the only file added to this folder; existing reports/logs were not modified._
