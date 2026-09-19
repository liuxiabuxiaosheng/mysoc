# Phase-Two Memory and CPU-Bus Verification

Verification date: 2026-09-19

This record covers the Phase-2 on-chip RAM, CPU request/response bus, CPU-to-APB bridge, and `soc_top` integration. It does not claim that an RV32I CPU, firmware, DMA, arbitration, CDC, audio, display, or FPGA synthesis implementation exists.

## Reproducing the Regression

From the repository root in PowerShell:

```powershell
git clean -fdX -- sim/build
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
```

The clean run exited with status 0 and printed these 13 passing tests:

1. `tb_smoke`
2. `tb_onchip_ram`
3. `tb_cpu_apb_bridge`
4. `tb_cpu_bus_decoder`
5. `tb_apb_gpio`
6. `tb_apb_timer`
7. `tb_uart_fifo`
8. `tb_uart_tx`
9. `tb_uart_rx`
10. `tb_uart_top`
11. `tb_apb_interconnect`
12. `tb_apb_subsystem`
13. `tb_soc_top`

Icarus Verilog 13.0 emitted existing warnings for RTL modules without an explicit time unit or time precision. The RAM initialization unit test also reports that its deliberately two-word HEX image is shorter than the full 16 KiB-word memory range; the remaining words were first initialized to zero and the test passed.

## Implemented CPU Bus

`soc_top` exposes a request/response interface for the future CPU:

- Request: `cpu_req_valid`, `cpu_req_write`, 32-bit address, 32-bit write data, and four byte-write strobes.
- Response: 32-bit read data, `cpu_resp_ready`, and `cpu_resp_error`.
- The decoder permits one outstanding request and latches request fields until completion.

The decoder maps aligned addresses `0x0000_0000` through `0x0000_FFFF` to on-chip RAM and routes aligned addresses `0x4000_0000` and above to the APB bridge. Unaligned accesses and addresses in the unmapped gap return a CPU-bus error without a RAM write. APB `PSLVERR` is forwarded as the CPU-bus error response; the APB data value is preserved.

## On-Chip RAM

`onchip_ram` implements 64 KiB as 16,384 32-bit words. It supports whole-word and independent byte-lane writes, with a synchronous response after a request is accepted. An optional HEX initialization-file parameter loads simulation/program contents; absent an image, all words initialize to zero. Reset returns the control FSM to idle but does not sequentially clear RAM data.

The RAM unit test verifies initialization, read timing, whole-word write, byte-strobe update, the final word at `0x0000_FFFC`, and rejection of an unaligned request without changing stored contents.

## APB Bridge and Integration

`cpu_apb_bridge` latches its request and drives APB Setup then Access. It holds address, direction, write data, and byte strobes stable throughout every APB wait cycle. It returns captured APB read data and error status only after `PREADY`.

The bridge unit test verifies Setup/Access sequencing, two wait cycles with changing upstream inputs, read-data transfer, and error propagation. The decoder integration test verifies CPU reads/writes to RAM and GPIO plus unaligned, RAM-range, decoder-gap, and APB-unmapped errors. The top-level test proves the same RAM and GPIO accesses through `soc_top` while retaining reset/default-output checks.

## RTL Elaboration Checks

Both synthesizable top-level elaboration checks exited with status 0:

```powershell
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

## Phase-Two Boundary

The current top-level CPU interface is driven by testbenches only. A multi-cycle RV32I core, firmware image generation, CPU/DMA RAM arbitration, and every later project phase remain unimplemented.
