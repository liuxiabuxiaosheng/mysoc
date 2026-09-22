# AX7010 Board-Top UART Bring-Up

## Configuration

- Implementation top: `board_top`.
- Device and board constraints: AX7010, 50 MHz PL clock, J19/K19 UART, M14 LED.
- Internal CPU: enabled.
- BRAM image: `firmware/hello_uart.hex`.
- UART message: `Hello RISC-V SoC\r\n` at the UART default divisor of 868.

## Simulation command

```powershell
powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test board_top
```

## Acceptance evidence

The test reports `PASS tb_board_top`, proves LED0 stays low in reset and becomes
high after synchronized release, decodes the complete 18-byte message, and
verifies the CPU did not halt.

## Boundary

This validates RTL simulation and a board-constrained top-level only. It does
not claim Vivado implementation, timing closure, bitstream download, or real
hardware UART capture.
