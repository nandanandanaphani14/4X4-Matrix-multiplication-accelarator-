# =====================================================================
# run_all_testbenches.ps1  --  re-verification regression driver
#
# Compiles the UNMODIFIED RTL (from the SIMPLE_ACCEL_RTL branch) together
# with the re-verification testbenches, runs each testbench in QuestaSim
# batch mode, stores one transcript per testbench under ../logs/, and
# writes a machine-readable regression_summary.txt.  Exits non-zero if any
# testbench fails (usable in CI).
# =====================================================================
$ErrorActionPreference = "Stop"

$root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)   # project root
$rtl  = Join-Path $root "4x4-systolic-array-multiplier-with-address-generator--SIMPLE_ACCEL_RTL\4x4-systolic-array-multiplier-with-address-generator--SIMPLE_ACCEL_RTL"
$tb   = $PSScriptRoot
$vr   = Split-Path -Parent $PSScriptRoot                        # verification_recheck
$logs = Join-Path $vr "logs"
$sim  = Join-Path $vr "sim"
New-Item -ItemType Directory -Force -Path $logs | Out-Null
New-Item -ItemType Directory -Force -Path $sim  | Out-Null
Set-Location $sim

# RTL compile order (leaf -> top)
$rtlFiles = @(
  "delay_pipe.sv","MAC.sv","array.sv","input_buf.sv","output_skewbuf.sv",
  "a_mem.sv","weight_mem.sv","outmem.sv","controller.sv","agu.sv",
  "wrapper_array_buf.sv","wrapper_mem_arr_buf.sv","wrapper_full_system.sv"
) | ForEach-Object { Join-Path $rtl $_ }

# testbench -> top module (same basename)
$tbs = @(
  "tb_delay_pipe","tb_processing_element","tb_memories",
  "tb_input_skew_buffer","tb_output_deskew_buffer","tb_systolic_array",
  "tb_array_buf_top","tb_controller","tb_agu",
  "tb_accelerator_top","tb_accelerator_system_top"
)

Write-Host "=== Building work library ==="
if (Test-Path work) { Remove-Item -Recurse -Force work }
& vlib work | Out-Null

$compileLog = Join-Path $logs "compile.log"
"Compile transcript - $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" | Out-File $compileLog -Encoding utf8

Write-Host "=== Compiling RTL ==="
$vlogRtl = & vlog -sv +incdir+"$tb" $rtlFiles 2>&1
$vlogRtl | Out-File $compileLog -Append -Encoding utf8
if ($LASTEXITCODE -ne 0) { $vlogRtl | Select-Object -Last 30; throw "RTL compile failed" }

Write-Host "=== Compiling testbenches ==="
foreach ($t in $tbs) {
  $vlogTb = & vlog -sv +incdir+"$tb" (Join-Path $tb "$t.sv") 2>&1
  $vlogTb | Out-File $compileLog -Append -Encoding utf8
  if ($LASTEXITCODE -ne 0) { $vlogTb | Select-Object -Last 30; throw "Compile failed for $t" }
}
Write-Host "Compilation OK (0 errors)"

$summary = Join-Path $logs "regression_summary.txt"
$header  = @()
$header += "QuestaSim re-verification regression - 4x4 weight-stationary systolic accelerator"
$header += "Run: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
$header += "Simulator: $((Get-Command vsim).Source)"
$header += ("-" * 68)
$header | Out-File $summary -Encoding utf8

$allPass = $true
foreach ($t in $tbs) {
  Write-Host "--- running $t ---"
  $log = Join-Path $logs "$t.log"
  & vsim -c -do "run -all; quit -f" $t 2>&1 | Tee-Object -FilePath $log | Out-Null

  $line = Select-String -Path $log -Pattern "TOTALS:\s*(\d+)\s*checks,\s*(\d+)\s*errors" | Select-Object -Last 1
  $res  = Select-String -Path $log -Pattern "RESULT:\s*(PASS|FAIL)" | Select-Object -Last 1
  if ($line -and $res) {
    $checks = $line.Matches[0].Groups[1].Value
    $errs   = $line.Matches[0].Groups[2].Value
    $verd   = $res.Matches[0].Groups[1].Value
  } else {
    $checks = "?"; $errs = "?"; $verd = "FAIL"
  }
  if ($verd -ne "PASS") { $allPass = $false }
  ("{0,-32} {1,-6} {2,6} checks  {3,4} errors" -f $t, $verd, $checks, $errs) |
    Tee-Object -FilePath $summary -Append | Out-Null
}

("-" * 68) | Out-File $summary -Append -Encoding utf8
$passCount = ($tbs).Count
if ($allPass) {
  "$passCount/$passCount testbenches passed" | Out-File $summary -Append -Encoding utf8
} else {
  "REGRESSION FAILED - see per-testbench logs" | Out-File $summary -Append -Encoding utf8
}

Get-Content $summary
if (-not $allPass) { exit 1 }
