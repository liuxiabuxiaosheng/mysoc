# Phase-One APB Peripheral Verification

Verification date: 2026-09-19

This document records only results observed in the phase-one verification run. It does not claim CPU, memory, DMA, audio, display, or AI integration.

## Tool versions

- `iverilog -V`: Icarus Verilog 13.0 (stable), `v13_0`.
- `vvp -V`: Icarus Verilog runtime 13.0 (stable), `v13_0`.
- Both version commands exited with status 0.

## Reproducing the regression

From the repository root in PowerShell:

```powershell
# Clean ignored generated simulation products under sim/build only.
git clean -fdX -- sim/build

# Run the full phase-one regression.
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test all
```

The runner treats every registered testbench as mandatory. `-Test all` throws immediately if any registered source file is missing rather than silently reducing coverage.

The clean regression exited with status 0 and printed the following ten passing testbench names, in this order:

1. `tb_smoke`
2. `tb_apb_gpio`
3. `tb_apb_timer`
4. `tb_uart_fifo`
5. `tb_uart_tx`
6. `tb_uart_rx`
7. `tb_uart_top`
8. `tb_apb_interconnect`
9. `tb_apb_subsystem`
10. `tb_soc_top`

Icarus emitted warnings that some design modules do not declare an explicit time unit or time precision. The warnings did not cause compilation or simulation failure in this run.

## RTL syntax checks

The same RTL file list was used for both top-level elaboration checks:

```powershell
$rtl = rg --files rtl -g '*.sv'
iverilog -g2012 -Wall -tnull -s apb_subsystem $rtl
iverilog -g2012 -Wall -tnull -s soc_top $rtl
```

Observed result: both `iverilog` commands exited with status 0.

## Implemented APB map

The interconnect implements three 4 KiB peripheral windows. A selected address outside these windows completes immediately with `PSLVERR=1` and read data `0xDEAD_BEEF`.

| Address window | Peripheral |
| --- | --- |
| `0x4000_0000`–`0x4000_0FFF` | GPIO |
| `0x4000_1000`–`0x4000_1FFF` | Timer |
| `0x4000_2000`–`0x4000_2FFF` | UART |

Each peripheral accepts only the register offsets listed below. An APB access to another offset within its window reports `PSLVERR`; invalid GPIO and timer reads return zero rather than data aliased through truncated address bits. The interconnect regression also covers two legal transfers to different peripheral windows with `PSEL` held high and only `PENABLE` lowered for the second setup phase.

### GPIO registers

| Absolute address | Offset | Register | Observed RTL behavior |
| --- | --- | --- | --- |
| `0x4000_0000` | `0x00` | `GPIO_DATA` | Read/write low 8-bit GPIO output value. |
| `0x4000_0004` | `0x04` | `GPIO_DIR` | Read/write low 8-bit GPIO direction value. |
| `0x4000_0008` | `0x08` | `GPIO_INPUT` | Read the second stage of a per-bit two-flop synchronizer; both stages clear asynchronously with peripheral reset. Writes have no state effect. |

### Timer registers

| Absolute address | Offset | Register | Observed RTL behavior |
| --- | --- | --- | --- |
| `0x4000_1000` | `0x00` | `TIMER_CTRL` | Bit 0 enables counting; bit 1 selects periodic operation. |
| `0x4000_1004` | `0x04` | `TIMER_COUNTER` | Current counter value; writes have no state effect. |
| `0x4000_1008` | `0x08` | `TIMER_COMPARE` | Compare value; reset value is 100. |
| `0x4000_100C` | `0x0C` | `TIMER_STATUS` | Bit 0 is the interrupt status/output; write one to bit 0 to clear it. |

### UART registers

| Absolute address | Offset | Register | Observed RTL behavior |
| --- | --- | --- | --- |
| `0x4000_2000` | `0x00` | `UART_DATA` | Write low 8 bits to the TX FIFO; read low 8 bits from the RX FIFO. Illegal disabled/full/empty accesses report `PSLVERR`; a valid RX read inserts one APB wait state. |
| `0x4000_2004` | `0x04` | `UART_STATUS` | Bits `[5:0]`: RX overflow sticky, RX frame-error sticky, RX full, RX empty, TX full, TX empty. |
| `0x4000_2008` | `0x08` | `UART_CTRL` | Bit 0 enables TX; bit 1 enables RX. Writing bit 8 requests clearing the sticky error flags. |
| `0x4000_200C` | `0x0C` | `UART_BAUD` | Baud divisor; reset value is 868 and writes below 8 are clamped to 8. The minimum-divider RX regression receives two consecutive frames without an idle transfer gap. |

## Phase-one boundaries

- `soc_top` deliberately drives an idle APB master (`PSEL=0`) until CPU and CPU-to-APB integration are implemented. The peripheral subsystem is therefore verified directly by its testbench, while the current board-facing top is only a reset/default-output smoke integration. `phase1_ready` remains low on external reset release and asserts only after synchronized reset release and the phase-one clock lock indication.
- `clk_gen` currently passes the 50 MHz board clock through and asserts a simple lock indication. It does not instantiate the Vivado Clocking Wizard.
- UART TX/RX and FIFO behavior are present, but this phase does not expose a UART interrupt output.
- BRAM, a CPU memory bus, an APB bridge, and a multi-cycle RV32I CPU are the next planned subproject.
- DMA, CDC/async FIFO integration, FIR, VGA/display, FFT, physical audio I/O, and AI functionality remain unimplemented.

## Next independent plan

The next subproject is to specify and verify BRAM, the CPU memory bus, the APB bridge, and a multi-cycle RV32I core with instruction-level tests. Later firmware, DMA/DSP, and full FPGA integration work must build on those verified interfaces rather than being treated as phase-one features.
