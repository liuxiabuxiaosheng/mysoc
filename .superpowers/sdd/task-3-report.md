# Task 3 Report: Sticky Timer Status

## RED

- Command: `powershell -ExecutionPolicy Bypass -File sim/run_tests.ps1 -Test apb_timer`
- Result before RTL change: FAIL at `one-shot expiry was not sticky` (the prior timer generated a one-cycle pulse; invalid offsets also did not report `PSLVERR`).

## GREEN

- `apb_timer`: `PASS tb_apb_timer`
- `apb_gpio`: `PASS tb_apb_gpio`
- `smoke`: `PASS tb_smoke`

## Files

- Added `tb/peripheral/tb_apb_timer.sv` with negedge reset release, one-shot sticky expiry/RW1C, periodic expiry/clear/re-expiry, and invalid-offset checks.
- Updated `rtl/peripheral/apb_timer.sv` to use one `always_ff` state process for control, counter, compare, and sticky status; terminal-count expiry; periodic/one-shot behavior; and APB `PSLVERR` on unsupported offsets.

## Commit

- `4526ee5 feat: add sticky timer status and periodic mode`

## Self-review

- Expiry assignment is ordered after APB status clear, so expiry wins on a simultaneous clear.
- `timer_irq` is continuously driven from `status_reg[0]`; status readback is at `0x0C` and writes are RW1C.
- No UART files were changed.

## Concerns

- The implementation uses SystemVerilog `always_ff`; it is accepted by the repository's Icarus/SystemVerilog simulation flow.
