param(
    [string]$ConstraintFile = (Join-Path $PSScriptRoot "..\constraints\ax7010_soc.xdc")
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $ConstraintFile)) {
    throw "Missing constraint file: $ConstraintFile"
}

$xdc = Get-Content -Raw $ConstraintFile
$requiredPatterns = @(
    'create_clock -name clk_50m -period 20\.000 -waveform \{0\.000 10\.000\} \[get_ports \{clk_50m\}\]',
    'PACKAGE_PIN U18 \[get_ports \{clk_50m\}\]',
    'PACKAGE_PIN N15 \[get_ports \{rst_n\}\]',
    'PACKAGE_PIN J19 \[get_ports \{uart_rx\}\]',
    'PACKAGE_PIN K19 \[get_ports \{uart_tx\}\]',
    'IOSTANDARD LVCMOS33'
)

foreach ($pattern in $requiredPatterns) {
    if ($xdc -notmatch $pattern) {
        throw "Missing required XDC entry: $pattern"
    }
}

Write-Output "AX7010_XDC_CHECK_PASS"
