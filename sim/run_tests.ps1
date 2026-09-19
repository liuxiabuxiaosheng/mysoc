param([string]$Test = "all")

$ErrorActionPreference = "Stop"
$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$BuildDir = Join-Path $ProjectRoot "sim\build"
New-Item -ItemType Directory -Force $BuildDir | Out-Null

$Tests = [ordered]@{
    smoke           = "tb/common/tb_smoke.sv"
    onchip_ram      = "tb/memory/tb_onchip_ram.sv"
    apb_gpio        = "tb/peripheral/tb_apb_gpio.sv"
    apb_timer       = "tb/peripheral/tb_apb_timer.sv"
    uart_fifo       = "tb/peripheral/tb_uart_fifo.sv"
    uart_tx         = "tb/peripheral/tb_uart_tx.sv"
    uart_rx         = "tb/peripheral/tb_uart_rx.sv"
    uart_top        = "tb/peripheral/tb_uart_top.sv"
    apb_interconnect = "tb/bus/tb_apb_interconnect.sv"
    apb_subsystem   = "tb/top/tb_apb_subsystem.sv"
    soc_top         = "tb/top/tb_soc_top.sv"
}

$Selected = if ($Test -eq "all") { @($Tests.Keys) } else { @($Test) }
foreach ($Name in $Selected) {
    if (-not $Tests.Contains($Name)) { throw "Unknown test: $Name" }
    $TbPath = Join-Path $ProjectRoot $Tests[$Name]
    if (-not (Test-Path $TbPath)) {
        throw "Testbench does not exist: $TbPath"
    }
    $Top = "tb_$Name"
    $Output = Join-Path $BuildDir "$Name.vvp"
    $Rtl = @(Get-ChildItem (Join-Path $ProjectRoot "rtl") -Recurse -Filter "*.sv" | ForEach-Object FullName)
    & iverilog -g2012 -Wall -I (Join-Path $ProjectRoot "tb\common") -s $Top -o $Output @Rtl $TbPath
    if ($LASTEXITCODE -ne 0) { throw "Compile failed: $Name" }
    & vvp $Output
    if ($LASTEXITCODE -ne 0) { throw "Simulation failed: $Name" }
}
