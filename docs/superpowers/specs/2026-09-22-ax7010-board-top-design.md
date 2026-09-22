# AX7010 Board Top and UART Bring-Up Design

Date: 2026-09-22  
Status: Approved design; awaiting specification review

## Goal

Create a board-specific AX7010 wrapper that boots the existing internal RV32IM
CPU from on-chip RAM and transmits `Hello RISC-V SoC\r\n` on UART. This is the
first board-validation milestone; audio, DMA, I2S, GPIO, timer, and interrupt
demonstrations are explicitly out of scope.

## Architecture

`board_top` is the implementation top-level. It exposes only real first-stage
board signals:

```text
clk_50m, rst_n, uart_rx -> board_top -> soc_top -> uart_tx
                                     |
                                     +-> phase1_ready -> led[0]
```

`board_top` instantiates `soc_top` with `INTERNAL_CPU=1'b1` and sets its RAM
initialization parameter to `firmware/hello_uart.hex`. It ties unused logical
inputs to safe constants and intentionally does not expose the simulation-only
external CPU request/response interface, audio clock, I2S, or GPIO ports.

## RTL Changes

### `rtl/top/soc_top.sv`

Add a string parameter `RAM_INIT_FILE` with the empty string as its default.
Pass that parameter to `onchip_ram.INIT_FILE`. Empty defaults preserve all
current testbench behavior.

### `rtl/top/board_top.sv`

Add a wrapper with ports `clk_50m`, `rst_n`, `uart_rx`, `uart_tx`, and
`led[0]`. Instantiate `soc_top` with the internal CPU enabled and the hello
firmware image selected. Map `phase1_ready` to `led[0]`.

## Firmware Image

Add `firmware/hello_uart.hex` as a 32-bit word-oriented `$readmemh` image.
It must configure the existing UART control and baud registers, poll UART TX
availability before each write, send the exact ASCII byte sequence
`Hello RISC-V SoC\r\n`, then loop forever. It must use only instructions
implemented by the current CPU.

The UART divisor and expected serial timing are derived from the existing UART
RTL and its testbench rather than assumed. The firmware must not halt after
printing the message.

## Verification

Add `tb/top/tb_board_top.sv` and register it in `sim/run_tests.ps1` as
`board_top`. The test must:

1. Assert and release reset.
2. Check `led[0]` only asserts after synchronous reset release.
3. Decode `uart_tx` with the configured divisor and require exactly
   `Hello RISC-V SoC\r\n`.
4. Confirm the internal CPU has not entered its fault/halted state while the
   message is being sent.

Existing regression tests must keep their current interfaces and behavior.

## Board Constraints

The existing AX7010 XDC must be retargeted to `board_top` after implementation.
Only its clock, reset, UART, and LED ports are in scope. I2S constraints remain
out of scope because no Codec, pin assignment, or I/O timing has been selected.

## Non-goals

- Vivado implementation, synthesis, timing closure, or bitstream download.
- External audio, I2S, DMA, FIR, GPIO, timer, or interrupt demonstrations.
- A compiler toolchain; this milestone uses a checked-in deterministic HEX
  image.
